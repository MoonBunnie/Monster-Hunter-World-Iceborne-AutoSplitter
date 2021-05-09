// AutoSplitter script for Monster Hunter World: Iceborne (by MoonBunnie & JalBagel)

//State for v15.11.00
state("MonsterHunterWorld")
{
  byte loading  : 0x5224B80, 0x146DB;
}

startup
{
  settings.Add("loadRemoval", true, "Load Removal");
}

isLoading
{
  return (current.loading == 0x01 && settings["loadRemoval"]);
}
