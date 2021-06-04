// AutoSplitter script for Monster Hunter World: Iceborne (by MoonBunnie & JalBagel)

//Supports v15.10+
state("MonsterHunterWorld"){}

startup {
  //Signatures for Base Pointer scans  
  vars.scanTargets = new Dictionary<string, SigScanTarget>();
  vars.scanTargets.Add("sMhGUI", new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 0F 28 74 24 40 48 8B B4 24 ?? ?? ?? ?? 8B 98"));
  vars.scanTargets.Add("sQuest", new SigScanTarget(7, "48 83 EC 48 48 8B 0D ?? ?? ?? ?? E8 ?? ?? ?? ?? 3C 01 0F 84 E0 00 00 00 48 8B 0D ?? ?? ?? ?? E8"));
  vars.scanTargets.Add("sEventDemo", new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 83 78 58 01 77 11"));
  vars.scanTargets.Add("sMhArea", new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 0F B6 80 EB D2 00 00 C3"));
  
  //Initialize Base Pointer dictionary
  vars.basePointers = new Dictionary<string, IntPtr>();
  foreach (KeyValuePair<string, SigScanTarget> entry in vars.scanTargets) {
    vars.basePointers.Add(entry.Key, IntPtr.Zero);
  }
  
  //Settings
  settings.Add("settings", true, "General Settings");
  settings.CurrentDefaultParent = "settings";
  settings.Add("loadRemoval", true, "Load Removal");
  settings.Add("cutsceneRemoval", false, "Cutscene Removal");
  settings.CurrentDefaultParent = null;
  
  settings.Add("splits_start", true, "Start Condition (Choose One)");
  settings.CurrentDefaultParent = "splits_start";
  settings.Add("splits_start_char", false, "Character Creation Finalized");
  settings.CurrentDefaultParent = null;
  
  settings.Add("splits_end", true, "End Condition (Choose One)");
  settings.CurrentDefaultParent = "splits_end";
  settings.Add("splits_end_1", false, "Land of Convergence");
  //settings.Add("splits_end_2", false, "Collosal Task");
  //settings.Add("splits_end_3", false, "History Books");
  //settings.Add("splits_end_4", false, "Paean of Guidance");
  settings.CurrentDefaultParent = null;
  
  //Force Game Time
  timer.CurrentTimingMethod = TimingMethod.GameTime;
}

init {
  //Base Pointer Scans
  foreach (KeyValuePair<string, SigScanTarget> entry in vars.scanTargets) {
    foreach (var page in memory.MemoryPages(true)) {
      //Skip pages outside of exe module
      if ((long)page.BaseAddress < (long)modules.First().BaseAddress || (long)page.BaseAddress > (long)modules.First().BaseAddress + modules.First().ModuleMemorySize) { continue;}
      
      //Get first scan result
      var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
      var ptr = scanner.Scan(entry.Value, 0x1);
      if (ptr != IntPtr.Zero) {
        vars.basePointers[entry.Key] = ptr + 0x4 + memory.ReadValue<int>(ptr);
        break;
      }
    }
  }

  //Setup Memory Watchers
  vars.isLoading = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sMhGUI"], 0x13F28, 0x1D04));
  vars.activeQuestId = new MemoryWatcher<int>(new DeepPointer(vars.basePointers["sQuest"], 0x4C));
  vars.activeQuestMainObj1State = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sQuest"], 0xDB));
  vars.activeQuestMainObj2State = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sQuest"], 0xF3));
  vars.cutsceneState = new MemoryWatcher<int>(new DeepPointer(vars.basePointers["sEventDemo"], 0x58));
  vars.areaStageID = new MemoryWatcher<int>(new DeepPointer(vars.basePointers["sMhArea"], 0x8058, 0xCC));
  vars.areaCharCreateState = new MemoryWatcher<int>(new DeepPointer(vars.basePointers["sMhArea"], 0x8058, 0x1D0));
  
  //Register Watchers
  vars.watchers = new MemoryWatcherList() {
    vars.isLoading,
    vars.activeQuestId,
    vars.activeQuestMainObj1State,
    vars.activeQuestMainObj2State,
    vars.cutsceneState
  };
}

update {
  //Update Memory Watchers
  vars.watchers.UpdateAll(game);
}

start {
  //For Character Creation Finalized
  if(settings["splits_start_char"]) {
    //Update Specific Watchers
    vars.areaStageID.Update(game);
    vars.areaCharCreateState.Update(game);
    
    if(vars.areaStageID.Current == 0 
      && vars.areaCharCreateState.Current == 10
      && vars.areaCharCreateState.Old == 9) {
      return true;
    }
  }
  return false;
}

split {
  //Split for Ending
  if(settings["splits_end_1"]
    && vars.activeQuestId.Current == 804
    && vars.activeQuestMainObj1State.Old != 5
    && vars.activeQuestMainObj1State.Current == 5) {
    return true;
  }
  return false;
}

isLoading {
  //Load Screen Check
  if ((vars.isLoading.Current == 1 || vars.isLoading.Current == 2) && settings["loadRemoval"]) {
    return true;
  }
  
  //Cutscene Check
    if (vars.cutsceneState.Current != 0 && settings["cutsceneRemoval"]) {
    return true;
  }
  
  return false;
}
