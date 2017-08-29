#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "0.0.1"

#include <sourcemod>
#include <weblync>
#include <morecolors>

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
	CreateConVar("sm_trade_helper_version", PLUGIN_VERSION, "Trade Helper Version", FCVAR_REPLICATED | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	
	LoadTranslations("common.phrases");
	
	RegConsoleCmd("sm_trade", CmdTrade, "Opens a trading menu for that target");
	RegConsoleCmd("sm_offer", CmdTrade, "Opens a trading menu for that target");
}

public Action CmdTrade(int iClient, int args)
{
	if (args < 1)
	{
		ReplyToCommand(iClient, "{lightseagreen}[Trade] {grey}%t", "No matching client");
		return Plugin_Handled;
	}
	
	char sBuffer[32], sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	bool bML;
	
	GetCmdArgString(sBuffer, sizeof sBuffer);
	
	int iTargetCount = ProcessTargetString(sBuffer, iClient, iTargets, sizeof iTargets, COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_BOTS, sTargetName, sizeof sTargetName, bML);
	
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "{lightseagreen}[Trade] {grey}%t", "No matching client");
		return Plugin_Handled;
	}
	
	if (iTargetCount >= 2)
	{
		ReplyToCommand(iClient, "{lightseagreen}[Trade] {grey}%t", "More than one client matched");
		return Plugin_Handled;
	}
	
	char sSteamID[32], Select_Query[512];
	
	GetClientAuthId(iTargets[0], AuthId_Steam2, sSteamID, sizeof sSteamID);
	
	Format(Select_Query, sizeof Select_Query, "SELECT `url` FROM trade_helper WHERE `steamid` = '%s'", sSteamID);
	
	DataPack pData = new DataPack();
	
	pData.WriteCell(iClient);
	pData.WriteCell(iTargets[0]);
	
	hDB.Query(OnDataFetched, Select_Query, pData);
	
	return Plugin_Handled;
}

public void OnDataFetched(Database db, DBResultSet results, const char[] error, DataPack pData)
{
	pData.Reset();
	
	int iClient = pData.ReadCell();
	int iTarget = pData.ReadCell();
}
