"""Mac CR2W preservation helpers for the body adapter. No game writes."""
import copy
import struct
import zlib

from prepare_lucy_assets import require


def nodes(value):
    pending = [value]
    while pending:
        node = pending.pop()
        yield node
        if isinstance(node, dict):
            pending.extend(node.values())
        elif isinstance(node, list):
            pending.extend(node)


def paths(value):
    for node in nodes(value):
        if isinstance(node, dict):
            path = node.get('DepotPath')
            if isinstance(path, dict) and path.get('$storage') == 'string':
                yield path['$value']


def remap_paths(value, mapping):
    count = 0
    for node in nodes(value):
        if isinstance(node, dict):
            path = node.get('DepotPath')
            if isinstance(path, dict) and path.get('$storage') == 'string' and path.get('$value') in mapping:
                path['$value'] = mapping[path['$value']]
                count += 1
    return count


def canonical(value):
    """Compare object graphs across WolvenKit's handle/buffer renumbering."""
    value = copy.deepcopy(value)
    handles, buffers = {}, {}
    for node in nodes(value):
        if isinstance(node, dict):
            for field, table in [('HandleId', handles), ('BufferId', buffers)]:
                if field in node:
                    table.setdefault(node[field], str(len(table)))
    for node in nodes(value):
        if isinstance(node, dict):
            for field in ['HandleId', 'HandleRefId', 'BufferId', 'BufferRefId']:
                if field in node:
                    table = handles if field.startswith('Handle') else buffers
                    require(node[field] in table, 'Unresolved object reference in body resource')
                    node[field] = table[node[field]]
    return value


def prepare_mac_write(document):
    """The installed WKit cannot name PLATFORM_Mac; write a known enum first."""
    document = copy.deepcopy(document)
    found = 0
    for node in nodes(document):
        if isinstance(node, dict) and 'cookingPlatform' in node:
            require(node['cookingPlatform'] in ['PLATFORM_None', 'PLATFORM_Mac'], 'Expected a Mac source resource')
            node['cookingPlatform'] = 'PLATFORM_PC'
            found += 1
    require(found > 0, 'No Mac cooking platform in resource')
    return document


def restore_mac_platform(raw):
    """Relocate the CR2W directory after restoring the unknown Mac enum name.

    Names and imports address the string pool; chunks and buffers address the
    file. Their contents, including opaque cooked physics, remain byte exact.
    Supported table layouts are the CR2W v195 format used by the body assets.
    """
    data = bytearray(raw)
    require(data[:4] == b'CR2W' and len(data) >= 160, 'Invalid CR2W body resource')
    tables = [list(struct.unpack_from('<III', data, 40 + i * 12)) for i in range(10)]
    require(not any(tables[i][1] for i in [6, 7, 8, 9]), 'Embedded CR2W resources need a separate adapter')
    start, length, _ = tables[0]
    require(start >= 160 and start + length <= len(data), 'Invalid CR2W string pool')
    pool = bytes(data[start:start + length])
    old, new = b'PLATFORM_PC\0', b'PLATFORM_Mac\0'
    require(pool.count(old) == 1 and new not in pool, 'Expected one generated PC platform marker')
    at, delta = pool.index(old), len(new) - len(old)
    data[start + at:start + at + len(old)] = new
    for table in tables[1:]:
        if table[0]:
            require(table[0] >= start + length, 'Unsupported CR2W table ordering')
            table[0] += delta
    tables[0][1] += delta
    tables[0][2] = zlib.crc32(data[start:start + tables[0][1]])
    h = 0xcbf29ce484222325
    for byte in new[:-1]:
        h = ((h ^ byte) * 0x100000001b3) & 0xffffffffffffffff
    for i in range(tables[1][1]):
        pos = tables[1][0] + i * 8
        offset, hash_ = struct.unpack_from('<II', data, pos)
        if offset == at:
            hash_ = (h >> 32) ^ (h & 0xffffffff)
        elif offset > at:
            offset += delta
        struct.pack_into('<II', data, pos, offset, hash_)
    for i in range(tables[2][1]):
        pos = tables[2][0] + i * 8
        offset = struct.unpack_from('<I', data, pos)[0]
        require(offset != at, 'Platform marker cannot be a resource import')
        if offset > at:
            struct.pack_into('<I', data, pos, offset + delta)
    for table_index, stride, field in [(4, 24, 12), (5, 24, 8)]:
        for i in range(tables[table_index][1]):
            pos = tables[table_index][0] + i * stride + field
            struct.pack_into('<I', data, pos, struct.unpack_from('<I', data, pos)[0] + delta)
    for table_index, stride in [(1, 8), (2, 8), (4, 24), (5, 24)]:
        pos, count, _ = tables[table_index]
        if count:
            tables[table_index][2] = zlib.crc32(data[pos:pos + count * stride])
    for pos in [24, 28]:
        struct.pack_into('<I', data, pos, struct.unpack_from('<I', data, pos)[0] + delta)
    for i, table in enumerate(tables):
        struct.pack_into('<III', data, 40 + i * 12, *table)
    struct.pack_into('<I', data, 32, 0xdeadbeef)
    struct.pack_into('<I', data, 32, zlib.crc32(data[:160]))
    return bytes(data)
