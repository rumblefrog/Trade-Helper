#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "0.0.1"

#include <sourcemod>
#include <weblync>

#pragma newdecls required

Database hDB;

public Plugin myinfo = 
{
	name = "Trade Helper",
	author = PLUGIN_AUTHOR,
	description = "Making your trading experience smoother",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	hDB = SQL_Connect("trade_helper", true, error, err_max);
	
	if (hDB == INVALID_HANDLE)
		return APLRes_Failure;
	
	char TableCreateSQL[] = "CREATE TABLE IF NOT EXISTS `trade_helper` ( `id` INT NOT NULL AUTO_INCREMENT , `steamid` VARCHAR(16) NOT NULL , `url` INT NOT NULL , `created_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`), UNIQUE (`steamid`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_general_ci;";
	
	SQL_SetCharset(hDB, "utf8mb4");
			
	hDB.Query(OnCharsetSet, "SET NAMES utf8");
	hDB.Query(OnTableCreate, TableCreateSQL);
	
	//RegPluginLibrary("Trade_Helper");

	return APLRes_Success;
}

public void OnCharsetSet(Database db, DBResultSet results, const char[] error, any pData) {}

public void OnTableCreate(Database db, DBResultSet results, const char[] error, any pData)
{
	if (results == null)
		SetFailState("Unable to create table: %s", error);
}

public void OnPluginStart()
{
	
}
