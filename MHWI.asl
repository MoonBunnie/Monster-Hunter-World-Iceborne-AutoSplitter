// AutoSplitter script for Monster Hunter World: Iceborne (by MoonBunnie & JalBagel)

//Supports v15.10+
state("MonsterHunterWorld")
{
}

startup
{
  //Signatures for Base Pointer scans  
  vars.scanTargets = new Dictionary<string, SigScanTarget>();
  vars.scanTargets.Add("sMhGUI", new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 0F 28 74 24 40 48 8B B4 24 ?? ?? ?? ?? 8B 98")); //Load Remover
  vars.scanTargets.Add("sQuest", new SigScanTarget(7, "48 83 EC 48 48 8B 0D ?? ?? ?? ?? E8 ?? ?? ?? ?? 3C 01 0F 84 E0 00 00 00 48 8B 0D ?? ?? ?? ?? E8")); //Quest Data
  
  //Initialize Base Pointer dictionary
  vars.basePointers = new Dictionary<string, IntPtr>();
  foreach (KeyValuePair<string, SigScanTarget> entry in vars.scanTargets) {
    vars.basePointers.Add(entry.Key, IntPtr.Zero);
  }
  
  //Settings
  settings.Add("loadRemoval", true, "Load Removal");
}

init
{
  //Base Pointer Scans
  foreach (KeyValuePair<string, SigScanTarget> entry in vars.scanTargets) {
    foreach (var page in memory.MemoryPages(true)) {
      //Skip pages outside of exe module
      if ((long)page.BaseAddress <= (long)modules.First().BaseAddress || (long)page.BaseAddress >= (long)modules.First().BaseAddress + modules.First().ModuleMemorySize) { continue;}
      
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
  vars.isLoading = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sMhGUI"], 0x146DB));
  vars.activeQuestId = new MemoryWatcher<byte>(new DeepPointer(vars.basePointers["sQuest"], 0x4C));
  
  //Register Watchers
  vars.watchers = new MemoryWatcherList() {
    vars.isLoading,
    vars.activeQuestId
  };
}

update {
  //Update Memory Watchers
  vars.watchers.UpdateAll(game);
}

isLoading
{
  return (vars.isLoading.Current == 0x01 && settings["loadRemoval"]);
}
