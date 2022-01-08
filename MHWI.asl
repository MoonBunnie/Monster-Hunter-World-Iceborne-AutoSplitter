// AutoSplitter script for Monster Hunter World: Iceborne (by MoonBunnie, JalBagel, GreenSpeed)

//Supports v15.10+
state("MonsterHunterWorld"){}

startup {
  //Signatures for Base Pointer scans  
  vars.scanTargets = new Dictionary<string, SigScanTarget>();
  vars.scanTargets.Add("sMhGUI", new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 0F 28 74 24 40 48 8B B4 24 ?? ?? ?? ?? 8B 98"));
  vars.scanTargets.Add("sQuest", new SigScanTarget(7, "48 83 EC 48 48 8B 0D ?? ?? ?? ?? E8 ?? ?? ?? ?? 3C 01 0F 84 E0 00 00 00 48 8B 0D ?? ?? ?? ?? E8"));
  vars.scanTargets.Add("sEventDemo", new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 83 78 58 01 77 11"));
  vars.scanTargets.Add("sMhArea", new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 0F B6 80 EB D2 00 00 C3"));
  
  //Settings
  settings.Add("settings", true, "General Settings");
  settings.CurrentDefaultParent = "settings";
  settings.Add("loadRemoval", true, "Load Removal");
  settings.Add("cutsceneRemoval", true, "Cutscene Removal");
  settings.CurrentDefaultParent = null;
  
  settings.Add("splits_start", true, "Start Condition (Choose One)");
  settings.CurrentDefaultParent = "splits_start";
  settings.Add("splits_start_char", false, "Character Creation Finalized");
  settings.CurrentDefaultParent = null;
  
  settings.Add("full_autosplit", true, "Full Autosplitting (Beta)");
  settings.CurrentDefaultParent = "full_autosplit";
  settings.Add("split_pinkian_tracks", true, "Include Pink Rathian Tracks Split");
  settings.Add("split_elder_tracks", true, "Include Elder Tracks Split");
  settings.Add("split_iceborne_tracks", true, "Include Splits For Iceborne Tracks");
  settings.Add("reset_on_game_close", false, "Reset On Game Close");
  
  // settings.CurrentDefaultParent = null;
  // settings.Add("splits_end", true, "End Condition (Choose One)");
  // settings.CurrentDefaultParent = "splits_end";
  // settings.Add("splits_end_1", false, "History Books");
  // settings.Add("splits_end_2", false, "Colossal Task");
  // settings.Add("splits_end_3", false, "Land of Convergence");
  //settings.Add("splits_end_4", false, "Paean of Guidance");
  settings.CurrentDefaultParent = null;
  
  //Force Game Time
  timer.CurrentTimingMethod = TimingMethod.GameTime;
  vars.timerModel = new TimerModel { CurrentState = timer };
}

init {
  //Initialize Rescan Params
  vars.scanErrors = 9999;
  vars.waitCycles = 0;
  
  //Initialize Base Pointer dictionary
  vars.basePointers = new Dictionary<string, IntPtr>();
  foreach (KeyValuePair<string, SigScanTarget> entry in vars.scanTargets) {
    vars.basePointers.Add(entry.Key, IntPtr.Zero);
  }
  
  //Define deferred init function, to support patch 15.11.01+ which introduced exe packing
  vars.init = (Func<bool>)(() => {
    if(vars.scanErrors == 0) { return true;} //Return true if init successful
    if(vars.waitCycles > 0 && vars.scanErrors > 0) { //Wait until next scan
      vars.waitCycles--;
      return false;
    }
    
    //Scan for Base Pointers
    vars.scanErrors = 0;
    foreach (KeyValuePair<string, SigScanTarget> entry in vars.scanTargets) {
      //Skip if already found
      if(vars.basePointers[entry.Key] != IntPtr.Zero) { continue;}
      
      var found = false;
      foreach (var page in memory.MemoryPages(true)) {
        //Skip pages outside of exe module
        if ((long)page.BaseAddress < (long)modules.First().BaseAddress || (long)page.BaseAddress > (long)modules.First().BaseAddress + modules.First().ModuleMemorySize) { continue;}
        
        //Get first scan result
        var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
        var ptr = scanner.Scan(entry.Value, 0x1);
        if (ptr != IntPtr.Zero) {
          vars.basePointers[entry.Key] = ptr + 0x4 + memory.ReadValue<int>(ptr);
          found = true;
          break;
        }
      }
      if (!found) { vars.scanErrors++;} //count remaining missing pointers
    }
    
    //finish init if all scans successful
    if (vars.scanErrors == 0) {
      //Setup Memory Watchers
      vars.loadDisplayState = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sMhGUI"], 0x13F28, 0x1D04));
      vars.activeQuestId = new MemoryWatcher<int>(new DeepPointer(vars.basePointers["sQuest"], 0x4C));
      vars.activeQuestMainObj1State = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sQuest"], 0xDB));
      //vars.activeQuestMainObj2State = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sQuest"], 0xF3));
      vars.cutsceneState = new MemoryWatcher<int>(new DeepPointer(vars.basePointers["sEventDemo"], 0x58));
      vars.areaStageId = new MemoryWatcher<int>(new DeepPointer(vars.basePointers["sMhArea"], 0x8058, 0xCC));
      vars.areaCharCreateState = new MemoryWatcher<int>(new DeepPointer(vars.basePointers["sMhArea"], 0x8058, 0x1D0));
      vars.objective1State = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sMhGUI"], 0x14078, 0x2EF4));
      vars.objective2State = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sMhGUI"], 0x14078, 0x31FC));
      vars.objective3State = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sMhGUI"], 0x14078, 0x3504));
      //vars.hudBannerDisplayState = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sMhGUI"], 0x14A68, 0x1D04)); 
      vars.hudPtr4 = new MemoryWatcher<int>(new DeepPointer(vars.basePointers["sMhGUI"], 0x14A38));
      vars.hudPtr5 = new MemoryWatcher<int>(new DeepPointer(vars.basePointers["sMhGUI"], 0x14A68));
      
      
      //Register Watchers
      vars.watchers = new MemoryWatcherList() {
        vars.loadDisplayState,
        vars.activeQuestId,
        vars.activeQuestMainObj1State,
        //vars.activeQuestMainObj2State,
        vars.cutsceneState,
        vars.areaStageId,
        vars.objective1State,
        vars.objective2State,
        vars.objective3State,
        //vars.hudBannerDisplayState,
        vars.hudPtr4,
        vars.hudPtr5
      };
      return true;
    }
    
    vars.waitCycles = 300; //set delay until next scan
    return false;
  });
  
  //Quest & Expedition Split Settings
  vars.questSplits = new Dictionary<int, List<string>>(); //key = Quest ID, value = list of valid conditions to split for
  vars.expeditionSplits = new Dictionary<int, List<string>>(); //key = Area ID, value = list of valid conditions to split for
  vars.loadedQuests = new Dictionary<int, bool>();

  vars.timesObj1Checked = 0;
  vars.timesObj2Checked = 0;
  vars.timesObj3Checked = 0;
  
  if(settings["full_autosplit"]) {
    // MR Check
    vars.isMR = false;

    // Xeno%
    vars.questSplits.Add(2, new List<string>{"cutscene4"}); //Astera
    vars.questSplits.Add(101, new List<string>{"complete"}); //7 Jagras
    vars.questSplits.Add(102, new List<string>{"checkbox1"}); //first check box for kestodons & again first check box for Great Jagras
    vars.questSplits.Add(103, new List<string>{"complete"}); //Great Jagras (quest only)
    vars.expeditionSplits.Add(101, new List<string>{"checkbox2"}); //HR 2 : Kulu Yaku Expedition, second check box for kill/capt
    vars.questSplits.Add(201, new List<string>{"complete"}); //Kulu Yaku (quest only)
    vars.questSplits.Add(205, new List<string>{"complete"}); //Pukei Pukei
    vars.questSplits.Add(301, new List<string>{"complete"}); //Barroth
    vars.questSplits.Add(302, new List<string>{"complete"}); //Jyuratodus
    vars.questSplits.Add(305, new List<string>{"complete"}); //Tobi Kadachi
    vars.questSplits.Add(306, new List<string>{"complete"}); //Anjanath
    vars.questSplits.Add(401, new List<string>{"cutscene2"}); //Zorah 1

    vars.questSplits.Add(405, new List<string>{"complete"}); //Paolumu
    vars.expeditionSplits.Add(104, new List<string>{"radobaan"}); //HR 7 : Radobaan Expedition, 2nd checkbox for kill, 1st check box for girros. 2nd Checkbox gets checked twice if capturing, so has its own split condition
    vars.questSplits.Add(407, new List<string>{"complete"}); //Radobaan (quest only)
    vars.questSplits.Add(408, new List<string>{"complete"}); //Legiana
    vars.questSplits.Add(501, new List<string>{"complete"}); //Odogaron
    vars.questSplits.Add(502, new List<string>{"complete"}); //Rathalos
    vars.questSplits.Add(503, new List<string>{"complete"}); //Diablos
    vars.questSplits.Add(504, new List<string>{"cutscene2"}); //Zorah 2

    vars.expeditionSplits.Add(102, new List<string>{"checkbox2"}); //HR 11 : HR Pukei Expedition, 2nd checkbox for kill/capt. Is there a 3rd for return?
    vars.questSplits.Add(601, new List<string>{"complete"}); //HR Pukei (quest only)
    vars.questSplits.Add(605, new List<string>{"complete"}); //HR Anjanath 
    if(settings["split_pinkian_tracks"]) vars.questSplits[605].Add("load"); //Pinkian Tracks on "load" of HR Anjanath Quest
    vars.questSplits.Add(607, new List<string>{"complete"}); //HR Pink Rathian
    vars.questSplits.Add(701, new List<string>{"complete"}); //HR Nergigante
    if(settings["split_elder_tracks"]) vars.questSplits[701].Add("load"); //Elder Tracks on "load" of HR Nergigante Quest
    vars.questSplits.Add(801, new List<string>{"complete"}); //HR Kushala Daora
    vars.questSplits.Add(802, new List<string>{"complete"}); //HR Teostra
    vars.questSplits.Add(803, new List<string>{"complete"}); //HR Vaal Hazak
    vars.questSplits.Add(804, new List<string>{"complete"}); //Split for Ending: Land of Convergence

    // Shara%
    vars.expeditionSplits.Add(108, new List<string>{"checkbox2"}); //Beotodus, Banbaro, Viper Tobi and Shrieking Legiana expeditions
    vars.questSplits.Add(1101, new List<string>{"complete"}); //Beotodus (quest only)
    vars.questSplits.Add(1102, new List<string>{"complete"}); //Banbaro (quest only)
    vars.questSplits.Add(1201, new List<string>{"complete"}); //Viper Tobi (quest only)
    vars.questSplits.Add(1202, new List<string>{"complete"}); //Nightshade Paolumu
    vars.questSplits.Add(1203, new List<string>{"complete"}); //Coral Pukei
    vars.questSplits.Add(1301, new List<string>{"complete"}); //Barioth
    vars.questSplits.Add(1302, new List<string>{"complete"}); //Nargacuga
    vars.questSplits.Add(1303, new List<string>{"complete"}); //Glavenus
    vars.questSplits.Add(1304, new List<string>{"complete"}); //Tigrex
    vars.questSplits.Add(1305, new List<string>{"complete"}); //Brachydios
    vars.questSplits.Add(1306, new List<string>{"complete"}); //Velkhana Repel

    vars.questSplits.Add(1401, new List<string>{"complete"}); //Shrieking Legiana (quest only)
    vars.questSplits.Add(1405, new List<string>{"complete"}); //Fulgur Anjanath
    vars.questSplits.Add(1402, new List<string>{"complete"}); //Acidic Glavenus
    vars.questSplits.Add(1403, new List<string>{"complete"}); //Ebony Odogaron
    vars.questSplits.Add(1404, new List<string>{"complete"}); //Velkhana Siege
    vars.questSplits.Add(1501, new List<string>{"complete"}); //Velkhana
    vars.expeditionSplits.Add(105, new List<string>{"mrcheckbox2"}); //Seething Bazelgeuse, needs special logic so the game doesn't split during first recess visit
    vars.questSplits.Add(1502, new List<string>{"complete"}); //Seething Bazelgeuse (quest only)
    vars.questSplits.Add(1503, new List<string>{"complete"}); //Blackveil
    vars.questSplits.Add(1504, new List<string>{"complete"}); //Namielle
    if(settings["split_iceborne_tracks"]){
      vars.questSplits[1503].Add("load"); //Blackveil tracks on "load" of quest
      vars.questSplits[1504].Add("load"); //Namielle tracks on "load" of quest
    } 
    vars.questSplits.Add(1601, new List<string>{"complete"}); //Ruiner Nergigante
    vars.questSplits.Add(1602, new List<string>{"complete"}); //Shara Ishvalda
  }
  
  //Instantiate Zorah and Astera variables (These quests don't have normal end conditions, so split by counting cutscenes)
  vars.cutscenesViewed = 0;

  //Instantiate Monster Tracks variables
  // vars.questLoaded = false;
}

update {
  //Perform updates only if init successful
  if(vars.init()){ 
    //Update Memory Watchers
    vars.watchers.UpdateAll(game);
    
    //Update States
    vars.isLoading = vars.loadDisplayState.Current == 1 || vars.loadDisplayState.Current == 2;
    vars.isLoadingStart = vars.loadDisplayState.Current == 1 && vars.loadDisplayState.Old == 0;
    vars.isCutscene = vars.cutsceneState.Current != 0;
    vars.isCutsceneStart = vars.cutsceneState.Current != 0 && vars.cutsceneState.Old == 0;
    vars.isExpedition = vars.activeQuestId.Current == -1 && (vars.areaStageId.Current < 301 || vars.areaStageId.Current > 307);  // no active quest, and not in town
    vars.isQuestComplete = vars.activeQuestMainObj1State.Current == 5 && vars.activeQuestMainObj1State.Old != 5;

    //Checkboxes
    vars.isObj1Complete = vars.objective1State.Current == 1 && vars.objective1State.Old == 0;
    vars.isObj2Complete = vars.objective2State.Current == 1 && vars.objective2State.Old == 0;
    vars.isObj3Complete = vars.objective3State.Current == 1 && vars.objective3State.Old == 0;
    vars.isObj1Checked = vars.objective1State.Current == 1;
    vars.isObj2Checked = vars.objective2State.Current == 1;
    vars.isObj3Checked = vars.objective3State.Current == 1;
    //vars.isQuestBannerActive = vars.isExpedition && vars.hudPtr4.Current != 0 && vars.hudPtr4.Current == vars.hudPtr5.Current;
    vars.isQuestBannerStarting = vars.isExpedition && vars.hudPtr4.Old == 0 && vars.hudPtr4.Current != 0 && vars.hudPtr4.Current == vars.hudPtr5.Current;
    
    //Track cutscenes & initial Quest Load
    if(vars.activeQuestId.Current != vars.activeQuestId.Old) {
      vars.cutscenesViewed = 0; //Reset cutscene count on quest change
      // vars.questLoaded = false; //Reset quest load state
    }
    if(vars.isCutsceneStart) vars.cutscenesViewed++; //Count cutscenes

    //Track checkbox counts
    if(vars.isObj1Complete) vars.timesObj1Checked++;
    if(vars.isObj2Complete) vars.timesObj2Checked++;
    if(vars.isObj3Complete) vars.timesObj3Checked++;

    //Reset checkboxes on stage change
    if(vars.areaStageId.Current != vars.areaStageId.Old){
      vars.timesObj1Checked = 0;
      vars.timesObj2Checked = 0;
      vars.timesObj3Checked = 0;
    }

    print("[DEBUG] " + vars.isMR);
  
  } else {
    return false;
  }
  
}

start {
  //For Character Creation Finalized
  if(settings["splits_start_char"]) {
    //Update Specific Watchers
    vars.areaCharCreateState.Update(game);
    
    if(vars.areaStageId.Current == 0 && vars.areaCharCreateState.Current == 10 && vars.areaCharCreateState.Old == 9) return true;
  }
  return false;
}

split {
  //Split for Quests on complete
  if(vars.isQuestComplete && vars.questSplits.ContainsKey(vars.activeQuestId.Current) && vars.questSplits[vars.activeQuestId.Current].Contains("complete")){
    if(vars.activeQuestId.Current == 804) vars.isMR = true; //Killing xeno means master rank has been entered
    return true;
  } 
  
  //Split for Quests as objectives complete
  if(vars.isObj1Complete && vars.questSplits.ContainsKey(vars.activeQuestId.Current) && vars.questSplits[vars.activeQuestId.Current].Contains("checkbox1")) return true;
  if(vars.isObj2Complete && vars.questSplits.ContainsKey(vars.activeQuestId.Current) && vars.questSplits[vars.activeQuestId.Current].Contains("checkbox2")) return true;
  if(vars.isObj3Complete && vars.questSplits.ContainsKey(vars.activeQuestId.Current) && vars.questSplits[vars.activeQuestId.Current].Contains("checkbox3")) return true;
  
  //Split for Quests on cutscene counts
  if(vars.isCutsceneStart && vars.questSplits.ContainsKey(vars.activeQuestId.Current)) {
    if(vars.questSplits[vars.activeQuestId.Current].Contains("cutscene2") && vars.cutscenesViewed == 2) {
      vars.cutscenesViewed = 0;
      return true;
    }
    if(vars.questSplits[vars.activeQuestId.Current].Contains("cutscene4") && vars.cutscenesViewed == 4) {
      vars.cutscenesViewed = 0;
      return true;
    }
  }
  
  //Split for Expeditions
  if(vars.isExpedition) {
    //Split as objectives complete
    if(vars.isObj1Complete && vars.expeditionSplits.ContainsKey(vars.areaStageId.Current) && vars.expeditionSplits[vars.areaStageId.Current].Contains("checkbox1")) return true;
    if(vars.isObj2Complete && vars.expeditionSplits.ContainsKey(vars.areaStageId.Current) && vars.expeditionSplits[vars.areaStageId.Current].Contains("checkbox2")) return true;
    if(vars.isObj3Complete && vars.expeditionSplits.ContainsKey(vars.areaStageId.Current) && vars.expeditionSplits[vars.areaStageId.Current].Contains("checkbox3")) return true;

    // Split for radobaan
    if(vars.isObj2Complete && vars.timesObj2Checked == 2 && vars.expeditionSplits.ContainsKey(vars.areaStageId.Current) && vars.expeditionSplits[vars.areaStageId.Current].Contains("radobaan")) return true;
    
    // Split for seething bazelgeuse
    if(vars.isObj2Complete 
      && vars.expeditionSplits.ContainsKey(vars.areaStageId.Current) 
      && vars.expeditionSplits[vars.areaStageId.Current].Contains("mrcheckbox2")
      && vars.isMR) return true;
  }
  
  //Split for tracks / on first quest load screen
  if(vars.isLoadingStart) {
    //Update so doesn't retrigger on subsequent loading screens
    if(!vars.loadedQuests.ContainsKey(vars.activeQuestId.Current)){
      vars.loadedQuests.Add(vars.activeQuestId.Current, true);
      if(vars.questSplits.ContainsKey(vars.activeQuestId.Current) && vars.questSplits[vars.activeQuestId.Current].Contains("load")) return true;
    }
    
  }
  
  return false;
}

isLoading {
  //Load Screen Check
  if (vars.isLoading && settings["loadRemoval"]) return true;
  
  //Cutscene Check
  if (vars.isCutscene && settings["cutsceneRemoval"]) return true;
  
  return false;
}

exit {
  if(settings["reset_on_game_close"]) vars.timerModel.Reset();
}
