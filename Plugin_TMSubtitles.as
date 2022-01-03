#name "TMSubtitles"
#author "Vjeux"
#perms "full"

[Setting name="Active" description="Plugin State"]
bool active = true;

Resources::Font@ g_font;
Resources::Font@ g_fontBold;
Resources::Font@ g_fontIcons;

float g_currentTime = 0;

uint g_currentGear = 1;
bool g_isGroundContact = true;
float g_lastGroundContactTime = 0;
bool g_isPressingAcceleration = true;
float g_lastPressingAccelerationTime = 0;
bool g_isWetTire = false;
bool g_isDrifting = false;
bool g_isSteerMacro = false;
float g_lastAbsSteer = 0;
float g_lastSteerMacroTime = 0;

void RenderMenu() {
  if (UI::BeginMenu("TMSubtitles")) {
    active = UI::Checkbox("Addon active", active);
    UI::EndMenu();
  }
}

array<Message@> g_messages;

class Message {
  string type;
  string message;
  float time;

  Message(string message_, string type_) {
    message = message_;
    time = g_currentTime;
    type = type_;
  }

  bool shouldBeDisplayed() {
    float displayTime = 1000;
    return g_currentTime < time + displayTime;
  }
}

void Update(float dt) {
  g_currentTime += dt;
}

void Main() {
  @g_font = Resources::GetFont("DroidSans.ttf");
  @g_fontBold = Resources::GetFont("DroidSans-Bold.ttf");
  @g_fontIcons = Resources::GetFont("ManiaIcons.ttf");
}

void setMinWidth(int width) {
  UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(0, 0));
  UI::Dummy(vec2(width, 0));
  UI::PopStyleVar();
}

void Render() {
  auto visState = GetViewingPlayerState();
  if (visState is null) {
    return;
  }

  if (visState.CurGear != g_currentGear) {
    string msg = "";
    if (visState.CurGear > g_currentGear) {
      msg = "Gear up to " + visState.CurGear;
    } else {
      msg = "Gear down to " + visState.CurGear;
    }
    Message@ messageObj = Message(msg, "gear");
    bool isCoalsced = false;
    for (uint i = 0; i < g_messages.Length; ++i) {
      if (g_messages[i].type == "gear") {
        g_messages.RemoveAt(i);
        g_messages.InsertAt(i, messageObj);
        isCoalsced = true;
        break;
      }
    }
    if (!isCoalsced) {
      g_messages.InsertLast(messageObj);
    }
    g_currentGear = visState.CurGear;
  }

  // Ground Contact
  bool isGroundContact =
    visState.FLGroundContactMaterial != 80 ||
    visState.FRGroundContactMaterial != 80 ||
    visState.RLGroundContactMaterial != 80 ||
    visState.RRGroundContactMaterial != 80;

  if (isGroundContact != g_isGroundContact) {
    if (isGroundContact) {
      string msg = "Air time (" + Math::Round(g_currentTime - g_lastGroundContactTime) + "ms)";
      g_messages.InsertLast(Message(msg, "airtime"));
    } else {
      g_lastGroundContactTime = g_currentTime;
    }
    g_isGroundContact = isGroundContact;
  }

  // Release
  bool isPressingAcceleration = visState.InputGasPedal > 0;
  if (isPressingAcceleration != g_isPressingAcceleration) {
    if (isPressingAcceleration) {
      string msg = "Release (" + Math::Round(g_currentTime - g_lastPressingAccelerationTime) + "ms)";
      g_messages.InsertLast(Message(msg, "release"));
    } else {
      g_lastPressingAccelerationTime = g_currentTime;
    }
    g_isPressingAcceleration = isPressingAcceleration;
  }

  // SteerMacro
  float absSteer = Math::Abs(visState.InputSteer);
  bool isSteerMacro =
    areFloatEpsilonEqual(absSteer, 0.1) ||
    areFloatEpsilonEqual(absSteer, 0.2) ||
    areFloatEpsilonEqual(absSteer, 0.3) ||
    areFloatEpsilonEqual(absSteer, 0.4) ||
    areFloatEpsilonEqual(absSteer, 0.5) ||
    areFloatEpsilonEqual(absSteer, 0.6) ||
    areFloatEpsilonEqual(absSteer, 0.7) ||
    areFloatEpsilonEqual(absSteer, 0.8) ||
    areFloatEpsilonEqual(absSteer, 0.9);
  if (isSteerMacro != g_isSteerMacro) {
    if (!isSteerMacro && g_currentTime - g_lastSteerMacroTime > 50) {
      string msg = "Macro " + (g_lastAbsSteer * 100) + "%";
      g_messages.InsertLast(Message(msg, "macrosteer"));
    } else {
      g_lastSteerMacroTime = g_currentTime;
    }
    g_lastAbsSteer = absSteer;
    g_isSteerMacro = isSteerMacro;
  }

  // Slipping Wet Tires
  bool isDrifting =
    visState.FLSlipCoef > 0 &&
    visState.FRSlipCoef > 0 &&
    visState.RLSlipCoef > 0 &&
    visState.RRSlipCoef > 0;
  if (isDrifting != g_isDrifting) {
    if (
      isDrifting &&
      visState.WetnessValue01 > 0 &&
      isGroundContact &&
      !isAnyWheelTouchingType(visState, EPlugSurfaceMaterialId::Water) &&
      !isAnyWheelTouchingType(visState, EPlugSurfaceMaterialId::WetDirtRoad) &&
      !isAnyWheelTouchingType(visState, EPlugSurfaceMaterialId::WetAsphalt) &&
      !isAnyWheelTouchingType(visState, EPlugSurfaceMaterialId::WetPavement) &&
      !isAnyWheelTouchingType(visState, EPlugSurfaceMaterialId::WetGrass)
    ) {
      string msg = "Slipping Wet Tires";
      g_messages.InsertLast(Message(msg, "wettires"));
    }
    g_isDrifting = isDrifting;
  }


  int windowFlags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoDocking;
  if (!UI::IsOverlayShown()) {
    windowFlags |= UI::WindowFlags::NoInputs;
  }

  UI::PushFont(g_font);
  UI::Begin("TMSubtitles", windowFlags);
  UI::BeginGroup();

  if (UI::BeginTable("table", 1, UI::TableFlags::SizingFixedFit)) {
    UI::TableNextRow();
    UI::TableNextColumn();
    setMinWidth(100);

//    UI::Text("" + visState.FLGroundContactMaterial);
//    UI::Text("Up = (" + c(visState.Up.x) + ", " + c(visState.Up.y) + ", " + c(visState.Up.z) + ")");
//    UI::Text("Dir = (" + c(visState.Dir.x) + ", " + c(visState.Dir.y) + ", " + c(visState.Dir.z) + ")");
//    vec3 carVel = normalize(visState.WorldVel);
//    UI::Text("WorldVel = (" + c(carVel.x) + ", " + c(carVel.y) + ", " + c(carVel.z) + ")");
//    vec3 diff = visState.Dir - carVel;
//    UI::Text("Diff = (" + c(diff.x) + ", " + c(diff.y) + ", " + c(diff.z) + ")");
//    float angle = angleBetweenTwoVec3(visState.Dir, carVel);
//    UI::Text("Angle = " + c(angle * 180 / Math::PI));

    for (uint i = 0; i < g_messages.Length; ++i) {
      if (g_messages[i].shouldBeDisplayed()) {
        UI::Text(g_messages[i].message);
      }
    }

    UI::EndTable();
  }

  UI::EndGroup();
  UI::End();
  UI::PopFont();
}

bool areFloatEpsilonEqual(float a, float b) {
  float epsilon = 0.00001;
  return a >= b - epsilon && a <= b + epsilon;
}

float dot3(vec3 a, vec3 b) {
  return (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
}

float angleBetweenTwoVec3(vec3 a, vec3 b) {
  float magA = magnitude3(a);
  float magB = magnitude3(b);
  if (magA == 0 || magB == 0) {
    return 0;
  }
  return Math::Acos(dot3(a, b) / magA * magB);
}

float magnitude3(vec3 v) {
  return Math::Sqrt((v.x * v.x) + (v.y * v.y) + (v.z * v.z));
}

vec3 normalize(vec3 v) {
   float length_of_v = magnitude3(v);
   if (length_of_v == 0) {
    return vec3(0, 0, 0);
   }
   return vec3(v.x / length_of_v, v.y / length_of_v, v.z / length_of_v);
}

float c(float f) {
  return Math::Round(f * 100) / 100;
}


bool isAnyWheelTouchingType(CSceneVehicleVisState@ visState, int type) {
  return
    visState.FLGroundContactMaterial == type ||
    visState.FRGroundContactMaterial == type ||
    visState.RLGroundContactMaterial == type ||
    visState.RRGroundContactMaterial == type;
}


// Functions borrowed from tm-dashboard
// https://github.com/codecat/tm-dashboard/

CSmPlayer@ GetViewingPlayer() {
  auto playground = GetApp().CurrentPlayground;
  if (playground is null || playground.GameTerminals.Length != 1) {
    return null;
  }
  return cast<CSmPlayer>(playground.GameTerminals[0].GUIPlayer);
}

CSceneVehicleVisState@ GetViewingPlayerState() {
  auto app = GetApp();

  auto sceneVis = app.GameScene;
  if (sceneVis is null) {
    return null;
  }
  CSceneVehicleVis@ vis = null;

  auto player = GetViewingPlayer();
  if (player !is null) {
    @vis = GetVis(sceneVis, player);
  } else {
    @vis = GetSingularVis(sceneVis);
  }

  if (vis is null) {
    return null;
  }

  uint entityId = GetEntityId(vis);
  if ((entityId & 0xFF000000) == 0x04000000) {
    // If the entity ID has this mask, then we are either watching a replay, or placing
    // down the car in the editor. So, we will check if we are currently in the editor,
    // and stop if we are.
    if (cast<CGameCtnEditorFree>(app.Editor) !is null) {
      return null;
    }
  }

  return vis.AsyncState;
}

// Get entity ID of the given vehicle vis.
uint GetEntityId(CSceneVehicleVis@ vis) {
  return Dev::GetOffsetUint32(vis, 0);
}

uint VehiclesManagerIndex = 4;
uint VehiclesOffset = 0x1C8;

// Get the only existing vehicle vis state, if there is only one. Otherwise, this returns null.
CSceneVehicleVis@ GetSingularVis(ISceneVis@ sceneVis) {
  auto vehicleVisMgr = GetMgr(sceneVis, VehiclesManagerIndex); // NSceneVehicleVis_SMgr
  if (vehicleVisMgr is null) {
    return null;
  }

  if (!CheckValidVehicles(vehicleVisMgr)) {
    return null;
  }

  auto vehiclesCount = Dev::GetOffsetUint32(vehicleVisMgr, VehiclesOffset + 0x8);
  if (vehiclesCount != 1) {
    return null;
  }

  auto vehicles = Dev::GetOffsetNod(vehicleVisMgr, VehiclesOffset);
  auto nodVehicle = Dev::GetOffsetNod(vehicles, 0);
  return Dev::ForceCast<CSceneVehicleVis@>(nodVehicle).Get();
}

// Gets a scene manager by its index. Prefer to use this instead of FindMgr, if you know the
// index.
CMwNod@ GetMgr(ISceneVis@ sceneVis, uint index) {
  uint managerCount = Dev::GetOffsetUint32(sceneVis, 0x8);
  if (index > managerCount) {
    error("Index out of range: there are only " + managerCount + " managers");
    return null;
  }

  return Dev::GetOffsetNod(sceneVis, 0x10 + index * 0x8);
}


uint16 g_offsetSpawnableObjectModelIndex = 0;

uint GetPlayerVehicleID(CSmPlayer@ player) {
  // When Vehicle is null, we're either playing offline, or we're spectating in multiplayer
  if (player.ScriptAPI.Vehicle !is null) {
    return player.ScriptAPI.Vehicle.Id.Value;
  }

  // Without the Vehicle object, we can find the ID at an offset in CSmPlayer
  if (g_offsetSpawnableObjectModelIndex == 0) {
    auto type = Reflection::GetType("CSmPlayer");
    if (type is null) {
      error("Unable to find reflection info for CSmPlayer!");
    }
    g_offsetSpawnableObjectModelIndex = type.GetMember("SpawnableObjectModelIndex").Offset - 0x14;
  }

  // Get the ID and make sure it actually matches the 0x02000000 mask
  uint maybeID = Dev::GetOffsetUint32(player, g_offsetSpawnableObjectModelIndex);
  //print("maybe ID = " + Text::Format("%08x", maybeID));
  if (maybeID & 0xFFF00000 == 0x02000000) {
    return maybeID;
  }

  // Not found :(
  return 0;
}

CSceneVehicleVis@ GetVis(ISceneVis@ sceneVis, CSmPlayer@ player) {
  uint vehicleEntityId = GetPlayerVehicleID(player);

  auto vehicleVisMgr = GetMgr(sceneVis, VehiclesManagerIndex); // NSceneVehicleVis_SMgr
  if (vehicleVisMgr is null) {
    return null;
  }

  if (!CheckValidVehicles(vehicleVisMgr)) {
    return null;
  }

  auto vehicles = Dev::GetOffsetNod(vehicleVisMgr, VehiclesOffset);
  auto vehiclesCount = Dev::GetOffsetUint32(vehicleVisMgr, VehiclesOffset + 0x8);

  for (uint i = 0; i < vehiclesCount; i++) {
    auto nodVehicle = Dev::GetOffsetNod(vehicles, i * 0x8);
    auto nodVehicleEntityId = Dev::GetOffsetUint32(nodVehicle, 0);

    if (vehicleEntityId != 0 && nodVehicleEntityId != vehicleEntityId) {
      continue;
    } else if (vehicleEntityId == 0 && (nodVehicleEntityId & 0x02000000) == 0) {
      continue;
    }

    return Dev::ForceCast<CSceneVehicleVis@>(nodVehicle).Get();
  }

  return null;
}

bool CheckValidVehicles(CMwNod@ vehicleVisMgr) {
  auto ptr = Dev::GetOffsetUint64(vehicleVisMgr, VehiclesOffset);
  auto count = Dev::GetOffsetUint32(vehicleVisMgr, VehiclesOffset + 0x8);

  // Ensure this is a valid pointer
  if ((ptr & 0xF) != 0) {
    return false;
  }

  // Assume we can't have more than 1000 vehicles
  if (count > 1000) {
    return false;
  }

  return true;
}