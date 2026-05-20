# TweakDB Binary Format Notes

Status: research note for read-only CyberMac analysis. This does not define a patcher yet and does not justify mutating shipped game files.

## Implementations Inspected

- WolvenKit `TweakDB.cs`: `Magic = 0x0BB1DB47`, `BlobVersion = 8`, `ParserVersion = 4`, and `RecordsSeed = 0x5EEDBA5E`.
  <https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.RED4/TweakDB/TweakDB.cs>
- WolvenKit `Header.cs` and `Structs.cs`: concrete file header fields and offsets.
  <https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.RED4/TweakDB/Header.cs>
  <https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.RED4/TweakDB/Structs.cs>
- WolvenKit `TweakDBReader.cs` / `TweakDBWriter.cs`: section read/write order and typed flat value encoding.
  <https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.RED4/TweakDB/TweakDBReader.cs>
  <https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.RED4/TweakDB/TweakDBWriter.cs>
- WolvenKit `TweakDBID.cs`: `TweakDBID = CRC32(name) | (UInt64(name.length) << 32)`.
  <https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.RED4/Types/Primitives/Simples/TweakDBID.cs>
- WolvenKit binary reader extensions: RED4 signed VLQ length-prefixed strings.
  <https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.Core/Extensions/BinaryReaderExtensions.cs>
- TweakXL runtime handling: `CreateRecord`, `CloneRecord`, `SetFlat`, flat type reflection, and engine load hooks.
  <https://github.com/psiberx/cp2077-tweak-xl/blob/master/src/Red/TweakDB/Manager.cpp>
  <https://github.com/psiberx/cp2077-tweak-xl/blob/master/src/Red/TweakDB/Buffer.cpp>
  <https://github.com/psiberx/cp2077-tweak-xl/blob/master/src/Red/TweakDB/Reflection.cpp>
  <https://github.com/psiberx/cp2077-tweak-xl/blob/master/src/Red/TweakDB/Raws.hpp>

## Header

The real Mac files `Data/r6/cache/tweakdb.bin` and `Data/r6/cache/tweakdb_ep1.bin` match the WolvenKit header:

- `magic`: `0x0BB1DB47`
- `blobVersion`: `8`
- `parserVersion`: `4`
- `recordsChecksum`: 32-bit checksum value
- `flatsOffset`: offset of the flat/value table
- `recordsOffset`: offset of the record table
- `queriesOffset`: offset of the query table
- `groupTagsOffset`: offset of the group tag table

The base Mac `tweakdb.bin` observed during this pass has:

- `flatsOffset = 0x00000020`
- `recordsOffset = 0x0252e7a1`
- `queriesOffset = 0x02732aed`
- `groupTagsOffset = 0x02807f85`

## Section Layout

WolvenKit reads the blob in this order:

1. File header.
2. Flats pool.
3. Records table.
4. Queries table.
5. Group tags table.

CyberMac's `inspect-tweakdb-structure` names these sections conservatively and reports confidence. A derived `stringNameValues` section may also be reported when string-bearing flat types are parsed, but that is not an independent header section.

## Flats And Values

The flats pool starts with a signed 32-bit flat type count. Each type descriptor is:

- `UInt64 typeHash`
- `UInt32 valueCount`
- `UInt32 keyCount`
- `UInt32 offset`

At each descriptor offset, WolvenKit reads:

- `UInt32 numValues`
- `numValues` typed values
- `UInt32 numKeys`
- `numKeys` pairs of `TweakDBID flatID` and `Int32 valueIndex`

Flat type hashes are FNV1a64 hashes of names such as `CName`, `String`, `TweakDBID`, `Float`, `Bool`, `Int32`, and array variants such as `array:TweakDBID`.

String and `CName` flat values are not MessagePack strings and are not a single global string/name pool. They use RED4 length-prefixed strings: signed VLQ `Int32`, then UTF-8 bytes when the prefix is negative or UTF-16 code units when the prefix is positive.

## Records

The record table starts with a signed 32-bit count. Each entry is:

- `UInt64 recordID`
- `UInt32 recordTypeHash`

Record IDs are `TweakDBID` values, not plaintext names. For a known candidate name, CyberMac can compute the ID and find the record entry. Record type hashes use Murmur3_32 with seed `0x5EEDBA5E`.

Known item records such as `Items.TShirt_04_old_01` are therefore resolved by computing `TweakDBID("Items.TShirt_04_old_01")` and looking for that value in the record table. This is format-informed and does not rely on packed string heuristics.

## Queries And Group Tags

The query table starts with a count, then each query entry stores a `TweakDBID`, result count, and result record IDs. The group tag table starts with a count, then stores `TweakDBID` plus a byte tag.

These sections are mapped but not yet semantically decoded by CyberMac beyond counts and samples.

## Record Properties And Flats

Record data is expressed by flats keyed as `TweakDBID("<record>.<property>")`. For item tracing, CyberMac currently uses known `gamedataItem_Record` property names from WolvenKit-generated classes to look up concrete flat entries for requested records. This means tracing can go beyond string discovery when a known property is present, but it is not a complete schema browser yet.

The direct parent/base record is not an explicit field in the parsed record table. TweakXL performs clone/inherit behavior through runtime engine APIs, and WolvenKit's writer can emit record/flat deltas. CyberMac still needs more validation before claiming a complete offline clone workflow.

## Offline Mutation Risk

The current evidence does not support in-place extension of the shipped `tweakdb.bin`.

Adding a new record like `Items.atomiic_*` would require, at minimum:

- a new record table entry with the correct `TweakDBID` and record type hash
- new flat keys for all required properties
- correctly typed flat values in the appropriate flat type pools
- updated section sizes and following section offsets
- records checksum handling compatible with the game parser
- possible query table and group tag updates
- validation of any string/name/resource references the item needs

WolvenKit has writer support for TweakDB files and deltas. TweakXL avoids static file mutation by creating/cloning records and setting flats at runtime through RED4ext hooks. CyberMac should treat direct binary patching as unproven until a writer design can reproduce WolvenKit-compatible output and pass game-load validation.

## CyberMac Implementation Notes

- `inspect-tweakdb-structure` parses header fields, section offsets, flat type descriptors, records, queries, group tags, and known item flats.
- `trace-tweakdb-record` computes a record `TweakDBID`, finds the record table entry, and resolves known item property flats where present.
- Existing packed string and reference-table commands remain available, but are heuristic workflows and should not be used as proof of an editable record table.
