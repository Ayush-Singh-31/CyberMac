import Foundation

/// Isolated, read-only diagnostic for the Mac 2.5 script cache. Compilation is
/// checked separately; neither native log delivery nor visible rendering is assumed.
public struct RedscriptEquipProbeGenerator: Sendable {
    public init() {}

    public func source(itemIDs: [String]) throws -> String {
        let items = try RedscriptItemGrantGenerator.normalizeItemIDs(itemIDs)
        guard items.count <= 8, items.allSatisfy({ $0.utf8.count <= 255 }) else {
            throw CyberMacError.invalidInput("Equip probe supports at most eight item IDs, each at most 255 bytes.")
        }
        let checks = items.map {
            "    summary += \"\\n\" + CyberMacEquipProbeHelper.CheckRecord(owner, t\"\($0)\", \"\($0)\");"
        }.joined(separator: "\n")
        return Self.template.replacingOccurrences(of: "__RECORD_CHECKS__", with: checks)
    }

    private static let template = #"""
// CyberMac read-only equip probe v2. No grants, currency, quest facts or persistent fields.
// Observe at most 32 calls per EquipmentSystemPlayerData restore. The wrapped method
// always runs. Immediate equipped state is not proof of a rendered clothing model.
// FTLog is declared in the original cache; its output sink still needs a runtime test.
module CyberMacEquipProbe


@wrapMethod(SingleplayerMenuGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  let version: wref<inkText> = inkWidgetRef.Get(this.m_versionTextRef) as inkText;
  if IsDefined(version) {
    version.SetTextDirect("CYBERMAC SCRIPT EXECUTED / MENU");
    version.SetOpacity(1.0);
    version.SetVisible(true);
  }
  return result;
}

@wrapMethod(SingleplayerMenuGameController)
protected cb func OnGameVersionHoverOver(evt: ref<inkPointerEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if IsDefined(this.m_gameVersionAnim) {
    this.m_gameVersionAnim.Stop();
  }
  let version: wref<inkText> = inkWidgetRef.Get(this.m_versionTextRef) as inkText;
  if IsDefined(version) {
    version.SetTextDirect("CYBERMAC SCRIPT EXECUTED / MENU");
  }
  return result;
}

@wrapMethod(SingleplayerMenuGameController)
protected cb func OnGameVersionHoverOut(evt: ref<inkPointerEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if IsDefined(this.m_gameVersionAnim) {
    this.m_gameVersionAnim.Stop();
  }
  let version: wref<inkText> = inkWidgetRef.Get(this.m_versionTextRef) as inkText;
  if IsDefined(version) {
    version.SetTextDirect("CYBERMAC SCRIPT EXECUTED / MENU");
  }
  return result;
}

@wrapMethod(OnscreenMessageGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  let text: wref<inkText> = inkWidgetRef.Get(this.m_mainTextWidget) as inkText;
  if IsDefined(text) {
    text.SetTextDirect("CYBERMAC SCRIPT EXECUTED / HUD");
    text.SetOpacity(1.0);
    text.SetVisible(true);
    this.GetRootWidget().SetOpacity(1.0);
    this.GetRootWidget().SetVisible(true);
  }
  return result;
}

@wrapMethod(OnscreenMessageGameController)
protected cb func OnScreenMessageUpdate(value: Variant) -> Bool {
  let result: Bool = wrappedMethod(value);
  let message: SimpleScreenMessage = FromVariant<SimpleScreenMessage>(value);
  if message.isShown && StrBeginsWith(message.message, "CyberMac") {
    let text: wref<inkText> = inkWidgetRef.Get(this.m_mainTextWidget) as inkText;
    if IsDefined(text) {
      text.SetTextDirect(message.message);
      text.SetOpacity(1.0);
      text.SetVisible(true);
      this.GetRootWidget().SetOpacity(1.0);
      this.GetRootWidget().SetVisible(true);
    }
  }
  return result;
}

@addField(EquipmentSystemPlayerData)
private let cyberMacEquipProbeEvents: Int32;

@wrapMethod(EquipmentSystemPlayerData)
public final func OnRestored() -> Void {
  wrappedMethod();
  this.cyberMacEquipProbeEvents = 0;
  let owner: ref<GameObject> = this.GetOwner();
  if IsDefined(owner) && IsDefined(owner as PlayerPuppet) {
    let summary: String = "ready; read-only; next 32 equips observed";
__RECORD_CHECKS__
    CyberMacEquipProbeHelper.Report(owner, summary, "CyberMac probe ready. Equip a clothing item, then close inventory.");
  }
}

@wrapMethod(EquipmentSystemPlayerData)
private final func EquipItem(itemID: ItemID, slotIndex: Int32, opt blockActiveSlotsUpdate: Bool, opt forceEquipWeapon: Bool) -> Void {
  let before: Bool = this.IsEquipped(itemID);
  wrappedMethod(itemID, slotIndex, blockActiveSlotsUpdate, forceEquipWeapon);
  let owner: ref<GameObject> = this.GetOwner();
  if !IsDefined(owner) || !IsDefined(owner as PlayerPuppet) || this.cyberMacEquipProbeEvents >= 32 {
    return;
  }
  this.cyberMacEquipProbeEvents += 1;
  let tdbid: TweakDBID = ItemID.GetTDBID(itemID);
  let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(tdbid);
  let transaction: ref<TransactionSystem> = GameInstance.GetTransactionSystem(owner.GetGame());
  let quantity: String = "unavailable";
  let appearance: String = "unavailable";
  if IsDefined(transaction) {
    quantity = IntToString(transaction.GetItemQuantity(owner, itemID));
    appearance = NameToString(transaction.GetItemAppearance(owner, itemID));
  }
  let text: String = s"equip=\(this.cyberMacEquipProbeEvents)/32 item=\(TDBID.ToStringDEBUG(tdbid)) hash=\(TDBID.ToNumber(tdbid)) record=\(IsDefined(record)) qty=\(quantity) equipped_before=\(before) equipped_after_immediate=\(this.IsEquipped(itemID)) appearance=\(appearance)";
  CyberMacEquipProbeHelper.Report(owner, text, s"CyberMac #\(this.cyberMacEquipProbeEvents): \(TDBID.ToStringDEBUG(tdbid))\nrecord=\(IsDefined(record)) qty=\(quantity) equipped=\(this.IsEquipped(itemID))\nappearance=\(appearance)");
}

// Wardrobe visuals bypass the inventory EquipItem path.
@wrapMethod(EquipmentSystemPlayerData)
private final func EquipVisuals(item: ItemID) -> Void {
  wrappedMethod(item);
  let owner: ref<GameObject> = this.GetOwner();
  if !IsDefined(owner) || !IsDefined(owner as PlayerPuppet) || this.cyberMacEquipProbeEvents >= 32 {
    return;
  }
  this.cyberMacEquipProbeEvents += 1;
  let area: gamedataEquipmentArea = EquipmentSystem.GetEquipAreaType(item);
  let visual: ItemID = this.GetVisualItemInSlot(area);
  let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(item));
  let text: String = s"wardrobe=\(this.cyberMacEquipProbeEvents)/32 item=\(TDBID.ToStringDEBUG(ItemID.GetTDBID(item))) requested_hash=\(TDBID.ToNumber(ItemID.GetTDBID(item))) visual_hash_after_immediate=\(TDBID.ToNumber(ItemID.GetTDBID(visual))) record=\(IsDefined(record)) physical_equipped=\(this.IsEquipped(item))";
  CyberMacEquipProbeHelper.Report(owner, text, s"CyberMac wardrobe #\(this.cyberMacEquipProbeEvents): \(TDBID.ToStringDEBUG(ItemID.GetTDBID(item)))\nvisual hash=\(TDBID.ToNumber(ItemID.GetTDBID(visual))) record=\(IsDefined(record))");
}

public class CyberMacEquipProbeHelper extends IScriptable {
  public static func CheckRecord(owner: ref<GameObject>, tdbid: TweakDBID, label: String) -> String {
    let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(tdbid);
    let quantity: String = "unavailable";
    let transaction: ref<TransactionSystem> = GameInstance.GetTransactionSystem(owner.GetGame());
    if !IsDefined(record) {
      quantity = "not_queried_record_absent";
    } else {
      if IsDefined(transaction) {
        quantity = IntToString(transaction.GetItemQuantity(owner, ItemID.CreateQuery(tdbid)));
      }
    }
    return s"record_check item=\(label) hash=\(TDBID.ToNumber(tdbid)) record=\(IsDefined(record)) qty=\(quantity)";
  }

  public static func Report(owner: ref<GameObject>, text: String, screenText: String) -> Void {
    let message: SimpleScreenMessage;
    message.isShown = true;
    message.duration = 12.0;
    message.message = screenText;
    message.isInstant = true;
    let board: ref<IBlackboard> = GameInstance.GetBlackboardSystem(owner.GetGame()).Get(GetAllBlackboardDefs().UI_Notifications);
    if IsDefined(board) {
      board.SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(message), true);
    }
    FTLog("[CyberMacEquipProbe/v2] " + text);
  }
}

"""#
}
