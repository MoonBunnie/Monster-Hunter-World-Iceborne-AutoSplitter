state("MonsterHunterWorld")
{
  byte isLoading : 0x5224B80, 0x146DB;
}

startup
{
  settings.Add("loadRemoval", true, "Load Removal");
}

isLoading
{
  if (current.isLoading == 0x01 && settings["loadRemoval"])
  {
    return true;
  }
  return false;
}
