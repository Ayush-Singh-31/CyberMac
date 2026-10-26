import Foundation

/// A real inventory grant and equipment request, using the created instance ID.
/// Both vanilla duplicate and isolated Lucy packages use the same item IDs.
enum StandaloneClothingSource {
    struct Piece: Codable, Sendable, Equatable {
        let source: String
        let record: String
        let label: String
        let entityName: String?

        init(source: String, record: String, label: String, entityName: String? = nil) {
            self.source = source; self.record = record; self.label = label; self.entityName = entityName
        }
    }

    static let pieces: [Piece] = [
        .init(source: "Items.Vest_08_basic_01", record: "Items.CyberMac_Standalone_Jacket", label: "CyberMac Jacket"),
        .init(source: "Items.Shirt_01_basic_01", record: "Items.CyberMac_Standalone_Top", label: "CyberMac Top"),
        .init(source: "Items.Pants_09_basic_01", record: "Items.CyberMac_Standalone_Pants", label: "CyberMac Pants"),
        .init(source: "Items.Boots_01_basic_01", record: "Items.CyberMac_Standalone_Boots", label: "CyberMac Boots")
    ]

    static var lucyPieces: [Piece] {
        zip(pieces, ["jacket", "top", "pants", "boots"]).map { piece, key in
            .init(source: piece.source, record: piece.record,
                  label: piece.label.replacingOccurrences(of: "CyberMac ", with: "CyberMac Lucy "), entityName: "cybermac_lucy_" + key)
        }
    }

    static let jingujiPieces: [Piece] = [
        .init(source: "Items.TShirt_06_basic_01", record: "Items.CyberMac_Jinguji_Corset", label: "CyberMac Jinguji Corset - Black Silver", entityName: "cybermac_jinguji_corset"),
        .init(source: "Items.Pants_10_basic_01", record: "Items.CyberMac_Jinguji_Pants", label: "CyberMac Jinguji Judy Pants - Black", entityName: "cybermac_jinguji_pants"),
        .init(source: "Items.Boots_05_basic_01", record: "Items.CyberMac_Jinguji_Heels", label: "CyberMac Jinguji Chrome Heels", entityName: "cybermac_jinguji_heels")
    ]

    static var wardrobePieces: [Piece] { lucyPieces + jingujiPieces }

    static func selectedPieces(group: String) throws -> [Piece] {
        switch group {
        case "jinguji": return jingujiPieces
        case "lucy": return lucyPieces
        case "both": return wardrobePieces
        case "none": return []
        default: throw CyberMacError.invalidInput("Choose jinguji, lucy, both or none.")
        }
    }

    static func render(pieces: [Piece] = Self.pieces, showPhysicalClothes: Bool = false,
                       delivery: [Piece]? = nil, autoEquip: Bool = true) -> String {
        let selected = delivery ?? pieces
        let ids = selected.map { "t\"\($0.record)\"" }.joined(separator: ", ")
        let names = pieces.map { "    if id == t\"\($0.record)\" { return \"\($0.label)\"; }" }.joined(separator: "\n")
        let sources = pieces.map { "    if id == t\"\($0.record)\" { return t\"\($0.source)\"; }" }.joined(separator: "\n")
        let wardrobe = showPhysicalClothes && autoEquip ? """
        if !this.verifyOnly {
          let equipmentData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(this.player);
          if IsDefined(equipmentData) && equipmentData.IsVisualSetActive() {
            equipmentData.UnequipWardrobeSet();
            this.wardrobePaused = true;
          }
        }
        """ : ""
        let equipment = autoEquip ? """
        if eq.IsEquippable(this.player, data) {
          let request: ref<EquipRequest> = new EquipRequest();
          request.owner = this.player;
          // Equip the actual created instance, including its seed.
          request.itemID = data.GetID();
          request.slotIndex = 0;
          request.addToInventory = false;
          eq.QueueRequest(request);
        }
        """ : ""
        return #"""
module CyberMacStandaloneClothing

@addField(PlayerPuppet)
private let cyberMacStandaloneScheduled: Bool;

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  if !this.cyberMacStandaloneScheduled && this.IsControlledByLocalPeer() {
    this.cyberMacStandaloneScheduled = true;
    let callback: ref<CyberMacClothingCallback> = new CyberMacClothingCallback();
    callback.player = this;
    GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(callback, 3.0);
  }
  return result;
}

public class CyberMacClothingCallback extends DelayCallback {
  public let player: wref<PlayerPuppet>;
  public let verifyOnly: Bool;
  public let wardrobePaused: Bool;

  public func Call() -> Void {
    if !IsDefined(this.player) { return; }
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.player.GetGame());
    let eq: ref<EquipmentSystem> = GameInstance.GetScriptableSystemsContainer(this.player.GetGame()).Get(n"EquipmentSystem") as EquipmentSystem;
    if !IsDefined(ts) || !IsDefined(eq) {
      CyberMacClothingMessages.Show(this.player, "CyberMac: inventory or equipment system unavailable.");
      return;
    }
    \#(wardrobe)
    let items: [TweakDBID] = [\#(ids)];
    let found: Int32 = 0;
    let equipped: Int32 = 0;
    let missing: String = "";
    let i: Int32 = 0;
    while i < ArraySize(items) {
      let id: TweakDBID = items[i];
      let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(id);
      if IsDefined(record) {
        let data: wref<gameItemData> = ts.GetItemDataByTDBID(this.player, id);
        if !this.verifyOnly && !IsDefined(data) {
          ts.GiveItemByTDBID(this.player, id, 1);
          data = ts.GetItemDataByTDBID(this.player, id);
        }
        if IsDefined(data) {
          found += 1;
          if this.verifyOnly {
            if eq.IsEquipped(this.player, data.GetID()) { equipped += 1; }
          } else {
            \#(equipment)
          }
        } else { missing += " Inventory rejected " + CyberMacClothingMessages.Name(id) + "."; }
      } else { missing += " Missing record: " + CyberMacClothingMessages.Name(id) + "."; }
      i += 1;
    }
    if !this.verifyOnly {
      let check: ref<CyberMacClothingCallback> = new CyberMacClothingCallback();
      check.player = this.player;
      check.verifyOnly = true;
      check.wardrobePaused = this.wardrobePaused;
      GameInstance.GetDelaySystem(this.player.GetGame()).DelayCallback(check, 2.0);
    } else {
      if this.wardrobePaused { missing += " Wardrobe set disabled for this test; presets kept."; }
      if ItemID.IsValid(eq.GetActiveItem(this.player, gamedataEquipmentArea.Outfit)) {
        missing += " A full-body outfit is equipped and may hide the clothes.";
      }
      CyberMacClothingMessages.Show(this.player, "CyberMac: " + IntToString(found) + "/\#(selected.count) selected clothes in inventory; " + IntToString(equipped) + " equipped. \#(autoEquip ? "Check clothing inventory." : "Equip your chosen pieces in clothing inventory.") Wardrobe outfits can hide them." + missing);
    }
  }
}

@wrapMethod(InventoryDataManagerV2)
private final func GetInventoryItemDataInternal(owner: wref<GameObject>, itemData: wref<gameItemData>, opt itemRecord: wref<Item_Record>) -> InventoryItemData {
  let result: InventoryItemData = wrappedMethod(owner, itemData, itemRecord);
  if IsDefined(itemData) && StrBeginsWith(CyberMacClothingMessages.Name(ItemID.GetTDBID(itemData.GetID())), "CyberMac") {
    InventoryItemData.SetName(result, CyberMacClothingMessages.Name(ItemID.GetTDBID(itemData.GetID())));
    InventoryItemData.SetIconPath(result, CyberMacClothingMessages.DonorIcon(ItemID.GetTDBID(itemData.GetID()), Equals(this.m_ItemIconGender, ItemIconGender.Male)));
  }
  return result;
}

@wrapMethod(InventoryDataManagerV2)
private final func GetInventoryItemDataFromItemRecordInternal(itemRecord: ref<Item_Record>) -> InventoryItemData {
  let result: InventoryItemData = wrappedMethod(itemRecord);
  if IsDefined(itemRecord) && StrBeginsWith(CyberMacClothingMessages.Name(itemRecord.GetID()), "CyberMac") {
    InventoryItemData.SetName(result, CyberMacClothingMessages.Name(itemRecord.GetID()));
    InventoryItemData.SetIconPath(result, CyberMacClothingMessages.DonorIcon(itemRecord.GetID(), Equals(this.m_ItemIconGender, ItemIconGender.Male)));
  }
  return result;
}

@wrapMethod(UIInventoryItem)
public final func GetIconPath() -> String {
  let result: String = wrappedMethod();
  let source: TweakDBID = CyberMacClothingMessages.Source(this.GetTweakDBID());
  if source != this.GetTweakDBID() {
    return UIInventoryItemsManager.ResolveItemIconName(source, TweakDBInterface.GetItemRecord(source), this.m_manager);
  }
  return result;
}

@wrapMethod(UIInventoryItem)
public final func GetName() -> String {
  let result: String = wrappedMethod();
  let name: String = CyberMacClothingMessages.Name(this.GetTweakDBID());
  if IsStringValid(name) { return name; }
  return result;
}

@wrapMethod(OnscreenMessageGameController)
protected cb func OnScreenMessageUpdate(value: Variant) -> Bool {
  let result: Bool = wrappedMethod(value);
  let message: SimpleScreenMessage = FromVariant<SimpleScreenMessage>(value);
  if message.isShown && StrBeginsWith(message.message, "CyberMac:") {
    let text: wref<inkText> = inkWidgetRef.Get(this.m_mainTextWidget) as inkText;
    if IsDefined(text) {
      text.SetTextDirect(message.message);
      text.SetVisible(true);
      text.SetOpacity(1.0);
      this.GetRootWidget().SetVisible(true);
      this.GetRootWidget().SetOpacity(1.0);
    }
  }
  return result;
}

public class CyberMacClothingMessages extends IScriptable {
  public static func Source(id: TweakDBID) -> TweakDBID {
\#(sources)
    return id;
  }

  public static func DonorIcon(id: TweakDBID, useMale: Bool) -> String {
    return NameToString(IconsNameResolver.GetIconsNameResolver().TranslateItemToIconName(CyberMacClothingMessages.Source(id), useMale));
  }

  public static func Name(id: TweakDBID) -> String {
\#(names)
    return "";
  }

  public static func Show(player: ref<PlayerPuppet>, text: String) -> Void {
    let message: SimpleScreenMessage;
    message.isShown = true;
    message.duration = 25.0;
    message.message = text;
    message.isInstant = true;
    let board: ref<IBlackboard> = GameInstance.GetBlackboardSystem(player.GetGame()).Get(GetAllBlackboardDefs().UI_Notifications);
    if IsDefined(board) {
      board.SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(message), true);
    }
  }
}
"""#
    }
}
