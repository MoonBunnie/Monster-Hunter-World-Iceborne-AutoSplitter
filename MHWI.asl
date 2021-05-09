// AutoSplitter script for Monster Hunter World: Iceborne (by MoonBunnie & JalBagel)

//Supports v15.10+
state("MonsterHunterWorld")
{
}

startup
{
  //Params for Load Removal
  vars.scanTarget1 = new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 0F 28 74 24 40 48 8B B4 24 ?? ?? ?? ?? 8B 98");
  vars.basePtr1 = IntPtr.Zero;
  
  //Settings
  settings.Add("loadRemoval", true, "Load Removal");
}

init
{
  //Base Pointer Scans
  var ptr = IntPtr.Zero;
  foreach (var page in memory.MemoryPages(true)) {
    //Skip pages outside of exe module
    if ((long)page.BaseAddress <= (long)modules.First().BaseAddress || (long)page.BaseAddress >= (long)modules.First().BaseAddress + modules.First().ModuleMemorySize) { continue;}
    
    //Get first scan result
    var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
    ptr = scanner.Scan(vars.scanTarget1, 0x1);
    if (ptr != IntPtr.Zero) {
      //vars.basePtr1 = (long)ptr + 0x4 + memory.ReadValue<int>(ptr) - 0x0140000000;
      vars.basePtr1 = ptr + 0x4 + memory.ReadValue<int>(ptr);
      break;
    }
  }

  //Setup Memory Watchers
  vars.isLoading = new MemoryWatcher<byte>(new DeepPointer(vars.basePtr1, 0x146DB));
  
  //Register Watchers
  vars.watchers = new MemoryWatcherList() {
    vars.isLoading
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
