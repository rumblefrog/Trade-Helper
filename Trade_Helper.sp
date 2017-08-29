#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "0.0.1"

#include <sourcemod>
#include <weblync>
#include <morecolors>

#pragma newdecls required

Database hDB;

ConVar cTimeout;

int Client_Target[MAXPLAYERS + 1];
int AppID;

float fTimeout;

char Client_Target_URL[MAXPLAYERS + 1][255];

Regex TOU_Pattern;

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
	
	char TableCreateSQL[] = "CREATE TABLE IF NOT EXISTS `trade_helper` ( `id` INT NOT NULL AUTO_INCREMENT , `steamid` VARCHAR(32) NOT NULL , `url` VARCHAR(255) NOT NULL , `created_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`), UNIQUE (`steamid`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_general_ci;";
	
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
	
	cTimeout = CreateConVar("sm_trade_helper_timeout", "5.0", "Enable blocked logging", FCVAR_NONE, true, 0.0);
	
	fTimeout = cTimeout.FloatValue;
	cTimeout.AddChangeHook(OnTimeoutChanged);
	
	switch (GetEngineVersion())
	{
		case Engine_CSGO: AppID = 730;
		case Engine_TF2: AppID = 440;
	}
	
	RegexError CompileError;
	char RegexErr[255];
	
	TOU_Pattern = new Regex("steamcommunity\\.com\\/tradeoffer\\/new\\/\\?partner=[0-9]*&token=[a-zA-Z0-9_-]*", PCRE_CASELESS, RegexErr, sizeof RegexErr, CompileError);
	
	if (CompileError != REGEX_ERROR_NONE)
		SetFailState("Failed to compile regex: %s", RegexErr);
	
	RegConsoleCmd("sm_trade", CmdTrade, "Opens a trading menu for that target");
	RegConsoleCmd("sm_offer", CmdTrade, "Opens a trading menu for that target");
	
	RegConsoleCmd("sm_tradelink", CmdTradeLink, "Set/update your trade URL");
	
	RegAdminCmd("sm_resettrade", CmdResetTrade, ADMFLAG_GENERIC, "Reset trade offer URL for that target");
}

public void OnTimeoutChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fTimeout = cTimeout.FloatValue;
}

public Action CmdTrade(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "{lightseagreen}[Trade] {grey}Missing target.");
		return Plugin_Handled;
	}
	
	char sBuffer[64], sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	bool bML;
	
	GetCmdArgString(sBuffer, sizeof sBuffer);
	
	int iTargetCount = ProcessTargetString(sBuffer, iClient, iTargets, sizeof iTargets, COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_BOTS, sTargetName, sizeof sTargetName, bML);
	
	if (iTargetCount <= 0)
	{
		CReplyToCommand(iClient, "{lightseagreen}[Trade] {grey}No matching client.");
		return Plugin_Handled;
	}
	
	if (iTargetCount >= 2)
	{
		CReplyToCommand(iClient, "{lightseagreen}[Trade] {grey}More than one client matched.");
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
	
	Client_Target[iClient] = iTarget;
	
	char Target_Name[MAX_NAME_LENGTH], Target_SteamID[32], Target_String[MAX_NAME_LENGTH + 32];
	
	GetClientName(iTarget, Target_Name, sizeof Target_Name);
	GetClientAuthId(iTarget, AuthId_Steam2, Target_SteamID, sizeof Target_SteamID);
	Format(Target_String, sizeof Target_String, "%s (%s)", Target_Name, Target_SteamID);
	
	Menu mTrade = new Menu(mTrade_Handler);
	
	mTrade.SetTitle(Target_String);
	
	mTrade.AddItem("inv", "View Inventory");
	mTrade.AddItem("sr", "View SteamRep");
	
	if (results != null && results.RowCount >= 1)
	{	
		results.FetchRow();
		
		if (!results.IsFieldNull(0))
		{
			results.FetchString(0, Client_Target_URL[iClient], sizeof Client_Target_URL[]);
			
			if (!StrEqual(Client_Target_URL[iClient], ""))
				mTrade.AddItem("trade", "Open Trade Offer");
		}
	}
	
	mTrade.Display(iClient, MENU_TIME_FOREVER);
}

public int mTrade_Handler(Menu menu, MenuAction action, int iClient, int iItem)
{
	if (action == MenuAction_Select)
	{
		char sBuffer[32], sSteamID64[32], sURL[255];
		
		int iTarget = Client_Target[iClient];
		
		GetClientAuthId(iTarget, AuthId_SteamID64, sSteamID64, sizeof sSteamID64);
		
		menu.GetItem(iItem, sBuffer, sizeof sBuffer);
		
		if (StrEqual(sBuffer, "inv"))
		{	
			if (AppID != 0)
				Format(sURL, sizeof sURL, "https://steamcommunity.com/profiles/%s/inventory#%i", sSteamID64, AppID);
			else 
				Format(sURL, sizeof sURL, "https://steamcommunity.com/profiles/%s/inventory", sSteamID64);
				
			WebLync_OpenUrl(iClient, sURL);
			
			return;
		}
		
		if (StrEqual(sBuffer, "sr"))
		{
			Format(sURL, sizeof sURL, "https://steamrep.com/profiles/%s", sSteamID64);
			
			WebLync_OpenUrl(iClient, sURL);
			
			return;
		}
			
		if (StrEqual(sBuffer, "trade"))
		{	
			DataPack pData = new DataPack();
			
			pData.WriteCell(iClient);
			pData.WriteString(Client_Target_URL[iClient]);
			
			CPrintToChat(iTarget, "{lightseagreen}[Trade] {grey}Opening trade offer in %.1f second(s).", fTimeout);
			
			CreateTimer(fTimeout, TradeTimeout, pData);

			return;
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}

public Action TradeTimeout(Handle timer, DataPack pData)
{
	char sURL[255];
	
	pData.Reset();
	
	int iClient = pData.ReadCell();
	pData.ReadString(sURL, sizeof sURL);
	
	WebLync_OpenUrl(iClient, sURL);
}

public Action CmdTradeLink(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "{lightseagreen}[Trade] {grey}Missing trade offer URL.");
		return Plugin_Handled;
	}
	
	char sBuffer[128], sSteamID[32], sQuery[512];
	
	GetCmdArgString(sBuffer, sizeof sBuffer);
	GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof sSteamID);
	
	if (StrEqual(sBuffer, "clear"))
	{
		Format(sQuery, sizeof sQuery, "UPDATE `trade_helper` SET `url` = NULL WHERE `steamid` = '%s'", sSteamID);
		
		hDB.Query(OnDataUpdated, sQuery, iClient);
		
		return Plugin_Handled;
	}
	
	if (TOU_Pattern.Match(sBuffer) > 0)
	{
		char TOU[128], Escaped_TOU[255];
		
		TOU_Pattern.GetSubString(0, TOU, sizeof TOU);
		
		hDB.Escape(TOU, Escaped_TOU, sizeof Escaped_TOU);
		
		Format(sQuery, sizeof sQuery, "INSERT INTO `trade_helper` (`steamid`, `url`) VALUES ('%s', '%s') ON DUPLICATE KEY UPDATE `url` = 'https://%s'", sSteamID, Escaped_TOU, Escaped_TOU);
		
		hDB.Query(OnDataUpdated, sQuery, iClient);
	} else
		CPrintToChat(iClient, "{lightseagreen}[Trade] {grey}Invalid trade offer URL.");
	
	return Plugin_Handled;
}

public Action CmdResetTrade(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "{lightseagreen}[Trade] {grey}Missing target.");
		return Plugin_Handled;
	}
	
	char sBuffer[64], sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	bool bML;
	
	GetCmdArgString(sBuffer, sizeof sBuffer);
	
	int iTargetCount = ProcessTargetString(sBuffer, iClient, iTargets, sizeof iTargets, COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_BOTS, sTargetName, sizeof sTargetName, bML);
	
	if (iTargetCount <= 0)
	{
		CReplyToCommand(iClient, "{lightseagreen}[Trade] {grey}No matching client.");
		return Plugin_Handled;
	}
	
	if (iTargetCount >= 2)
	{
		CReplyToCommand(iClient, "{lightseagreen}[Trade] {grey}More than one client matched.");
		return Plugin_Handled;
	}
	
	char sSteamID[32], Update_Query[512];
	
	GetClientAuthId(iTargets[0], AuthId_Steam2, sSteamID, sizeof sSteamID);
	
	Format(Update_Query, sizeof Update_Query, "UPDATE `trade_helper` SET `url` = NULL WHERE `steamid` = '%s'", sSteamID);
	
	DataPack pData = new DataPack();
	
	pData.WriteCell(iClient);
	pData.WriteCell(iTargets[0]);
	
	hDB.Query(OnDataReset, Update_Query, iTargets[0]);
	
	return Plugin_Handled;
}

public void OnDataUpdated(Database db, DBResultSet results, const char[] error, int iClient)
{
	if (results != null)
		CPrintToChat(iClient, "{lightseagreen}[Trade] {grey}Updated your trade offer URL.");
	else
		LogError("Failed to update data: %s", error);
}

public void OnDataReset(Database db, DBResultSet results, const char[] error, DataPack pData)
{
	if (results != null)
	{
		pData.Reset();
		
		int iClient = pData.ReadCell();
		int iTarget = pData.ReadCell();
		
		CPrintToChat(iClient, "{lightseagreen}[Trade] {grey}Reset trade offer URL for %N.", iTarget);
	} else
		LogError("Failed to reset data: %s", error);
}