#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <shop>
#include <shop_games>

int		Commission;
int		ConfirmTime;
int		StartTime;
int		GameTime;
int		MinCredits;
int		MaxCredits;
KeyValues g_hKv;
Cookie	CookieResultMenu,
		CookieGames,
		CookieMinBet,
		CookieMaxBet;

bool	ClientCookieResult[MAXPLAYERS+1],
		g_bUseChat[MAXPLAYERS+1],
		g_bSetMinBet[MAXPLAYERS+1],
		g_bSetMaxBet[MAXPLAYERS+1],
		ClientCookie[MAXPLAYERS+1];

StringMap hGames = null;

bool g_bActive;

enum struct eGames
{
    char sName[64];
    Handle hPlugin;
	Function fncCallback;
}
eGames g_eGames[64];
ArrayList g_hGames;

enum GameOptions
{
	Game,
	bet,
	Target,
	Started
}

Handle g_hOnStart;
int Options[MAXPLAYERS+1][GameOptions];

public Plugin myinfo =
{
	name = "[Shop Core] Games",
	author = "Monroe, Pisex",
	version = "2.0"
};

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] sError, int iErrorMax)
{
    CreateNative("SG_RegisterGame", 	Native_RegisterGame);
    CreateNative("SG_ResetGame", 	    Native_ResetGame);
    CreateNative("SG_FinalGame", 	    Native_FinalGame);
	CreateNative("SG_GetEnemy", 		Native_GetEnemy);
	CreateNative("SG_IsClientPlay", 	Native_IsClientPlay);
	CreateNative("SG_IsStart", 			Native_IsStart);
	CreateNative("SG_GetGameTime", 		Native_GetGameTime);
	g_hOnStart = CreateGlobalForward("SG_OnStarted", ET_Ignore);
	RegPluginLibrary("shop_games");
	return APLRes_Success;
}

public int Native_GetGameTime(Handle hPlugin, int iNumParams)
{
	return GameTime;
}

public int Native_IsStart(Handle hPlugin, int iNumParams)
{
	return g_bActive;
}

public int Native_GetEnemy(Handle hPlugin, int iNumParams)
{
	return GetClientEnemy(GetNativeCell(1));
}

public int Native_IsClientPlay(Handle hPlugin, int iNumParams)
{
	return IsClientPlay(GetNativeCell(1));
}

public int Native_RegisterGame(Handle hPlugin, int iNumParams)
{
	char sResult[64];
	g_eGames[g_hGames.Length].hPlugin = hPlugin;
	g_eGames[g_hGames.Length].fncCallback = GetNativeFunction(3);
	GetNativeString(2,sResult,sizeof sResult);
	g_eGames[g_hGames.Length].sName = sResult;
	GetNativeString(1,sResult,sizeof sResult);
	hGames.SetValue(sResult, g_hGames.Length);
    g_hGames.PushString(sResult);
	return 0;
}

public void OnPluginStart()
{
    hGames = new StringMap();
    g_hGames = new ArrayList(ByteCountToCells(128));
	LoadConfig();

	RegConsoleCmd("sm_games", Command_Games, "Show main menu");

	AddCommandListener(HookPlayerChat, "say");
	AddCommandListener(HookPlayerChat, "say_team");

	if (Shop_IsStarted())
	{
		Shop_Started();
		RequestFrame(CallForward);
	}
}

void CallForward()
{
	Call_StartForward(g_hOnStart);
	Call_Finish();
}

public Action HookPlayerChat(int iClient, char[] command, int args)
{
	if(iClient < 1) return Plugin_Continue; 
	if(g_bUseChat[iClient])
	{
		char sResult[64];
		GetCmdArg(1, sResult, sizeof sResult);
		Options[iClient][bet] = StringToInt(sResult);

		if(Options[iClient][bet] < MinCredits)
		{
			PrintToChat(iClient, "%s Вы ввели меньше минимального порога.", GPREFIX);
			return Plugin_Handled;
		}
		if(MaxCredits != 0)
		{
			if(Options[iClient][bet] > MaxCredits)
			{
				PrintToChat(iClient, "%s Вы превысили максимальный порог.", GPREFIX);
				return Plugin_Handled;
			}
		}

		if (!IsValidClient(iClient, Options[iClient][bet]))
		{
			PrintToChat(iClient, "%s Недостаточно кредитов.", GPREFIX);
		}
		else
		{
			Format(sResult,sizeof sResult,"Ставка: %s кр.\n \n",sResult);
			ShowMenu_BetMenu(iClient,sResult, true);
		}
		return Plugin_Handled;
	}
	else if(g_bSetMinBet[iClient])
	{
		g_bSetMinBet[iClient] = false;
		char sResult[64];
		GetCmdArg(1, sResult, sizeof sResult);
		int iValue = StringToInt(sResult);

		if(iValue != 0 && iValue < MinCredits)
		{
			PrintToChat(iClient, "%s Вы ввели меньше минимального порога.", GPREFIX);
			return Plugin_Handled;
		}
		if(iValue != 0 && MaxCredits != 0 && iValue > MaxCredits)
		{
			PrintToChat(iClient, "%s Вы превысили максимальный порог.", GPREFIX);
			return Plugin_Handled;
		}
		SetCookieInt(iClient, CookieMinBet, iValue);

		ShowMenu_Settings(iClient);
		return Plugin_Handled;
	}
	else if(g_bSetMaxBet[iClient])
	{
		g_bSetMaxBet[iClient] = false;
		char sResult[64];
		GetCmdArg(1, sResult, sizeof sResult);
		int iValue = StringToInt(sResult);

		if(iValue != 0 && iValue < MinCredits)
		{
			PrintToChat(iClient, "%s Вы ввели меньше минимального порога.", GPREFIX);
			return Plugin_Handled;
		}
		if(iValue != 0 && MaxCredits != 0 && iValue > MaxCredits)
		{
			PrintToChat(iClient, "%s Вы превысили максимальный порог.", GPREFIX);
			return Plugin_Handled;
		}

		SetCookieInt(iClient, CookieMaxBet, iValue);
		
		ShowMenu_Settings(iClient);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	CookieGames = RegClientCookie("shop_game", "Ignoring the offer to play", CookieAccess_Private);
	CookieMinBet = RegClientCookie("shop_games_minbet", "Min bet play", CookieAccess_Private);
	CookieMaxBet = RegClientCookie("shop_games_maxbet", "Max bet play", CookieAccess_Private);
	CookieResultMenu = RegClientCookie("shop_game_result", "Off result menu", CookieAccess_Private);
	CheckAllClientsCookie();
}

public void OnClientPutInServer(client)
{
	CheckClientCookie(client);
}

public void OnClientDisconnect(client)
{
	Options[client][Started] = false;
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

stock void SetCookieInt(int client, Handle cookie, int value) {
    char buffer[20];
    IntToString(value, buffer, sizeof(buffer));
    SetClientCookie(client, cookie, buffer);
}

void LoadConfig()
{
	char path[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(path, sizeof(path), "games.cfg");

	g_hKv = new KeyValues("Games");

	g_hKv.ImportFromFile(path);
	g_hKv.Rewind();
	if(g_hKv.JumpToKey("Settings"))
	{
		Commission =	g_hKv.GetNum("commission",10);
		ConfirmTime =	g_hKv.GetNum("confirm_time",20);
		StartTime =		g_hKv.GetNum("start_time",3);
		GameTime =		g_hKv.GetNum("game_time",20);
		MinCredits =	g_hKv.GetNum("min_credits",100);
		MaxCredits =	g_hKv.GetNum("max_credits",50000);
	}
}

public int Rules_Handler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Cancel && param == MenuCancel_ExitBack)
	{
		ShowMenu_Rules(client);
	}
	return 0;
}

void CheckAllClientsCookie()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		CheckClientCookie(i);
	}
}

void CheckClientCookie(int client)
{
	if (IsValidClient(client))
	{
		char buffer[10];

		
		ClientCookie[client] = false;
		GetClientCookie(client, CookieGames, buffer, sizeof(buffer));

		if(StrEqual(buffer, "1"))
		{
			ClientCookie[client] = true;
		}

		GetClientCookie(client, CookieResultMenu, buffer, sizeof(buffer));

		if(StrEqual(buffer, "1"))
		{
			ClientCookieResult[client] = true;
		}
	}
}

public void Shop_Started()
{
	Shop_AddToFunctionsMenu(FunctionDisplay, FunctionSelect);
	g_bActive = true;
}

public FunctionDisplay(client, String:buffer[], maxlength)
{
	char title[64];
	FormatEx(title, sizeof(title), "%s [Комиссия: %i%%]", GTITLE, Commission);

	strcopy(buffer, maxlength, title);
}

public bool FunctionSelect(client)
{
	ShowMenu_Main(client);

	return true;
}

public Action Command_Games(int client, int args)
{
	if (IsValidClient(client))
	{
		ShowMenu_Main(client);
	}

	return Plugin_Handled;
}

void SetMenuTitleEx(Menu menu, int client)
{
	menu.SetTitle("%s\n ∟Кредитов: %i \n \n", GTITLE, Shop_GetClientCredits(client));
}

void ShowMenu_Main(int client)
{
	Menu menu = new Menu(Main_MenuHandler);
	SetMenuTitleEx(menu, client);

	menu.AddItem("", "Играть", Options[client][Started] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem("", "Правила");
	menu.AddItem("", "Настройки");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Main_MenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack)
	{
		Shop_ShowFunctionsMenu(client);
	}
	else if (action == MenuAction_Select)
	{
		switch (param)
		{
			case 0: ShowMenu_Games(client);
			case 2: ShowMenu_Rules(client);
			case 3: ShowMenu_Settings(client);
		}
	}
	return 0;
}

void ShowMenu_Games(int client)
{
	Menu menu = new Menu(Games_MenuHandler);
	SetMenuTitleEx(menu, client);

    char sBuffer[64], sBuffer2[12];
	for(int i = 0; i < g_hGames.Length; i++)
    {
        g_hGames.GetString(i,sBuffer,sizeof sBuffer);
        IntToString(i, sBuffer2, sizeof sBuffer2);
        menu.AddItem(sBuffer2, g_eGames[i].sName);
    }

	if (!menu.ItemCount)
	{
		menu.AddItem("", "Нет доступных игр", ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Games_MenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack)
	{
		ShowMenu_Main(client);
	}
	else if (action == MenuAction_Select)
	{
		Options[client][Game] = param;
		char sText[256];
		if(MinCredits == 0) 
			if(MaxCredits == 0) 
				FormatEx(sText,sizeof sText,"Введите ставку в чат\n \n");
			else
				FormatEx(sText,sizeof sText,"Введите ставку в чат (до %i)\n \n",MaxCredits);
		else
			if(MaxCredits == 0) 
				FormatEx(sText,sizeof sText,"Введите ставку в чат (от %i)\n \n",MinCredits);
			else
				FormatEx(sText,sizeof sText,"Введите ставку в чат (от %i до %i)\n \n",MinCredits,MaxCredits);

		ShowMenu_BetMenu(client,sText,false);
	}
	return 0;
}

void ShowMenu_BetMenu(int client,char[] Text, bool status)
{
	if(!status) g_bUseChat[client] = true;
	Menu menu = new Menu(BetMenu_MenuHandler);
	menu.SetTitle("%s \nПодтверждение ставки:\n \n", GTITLE);
	menu.AddItem("1", Text, ITEMDRAW_DISABLED);
	menu.AddItem("2", "Согласен", status?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.AddItem("3", "Изменить ставку", status?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client,0);
}

public int BetMenu_MenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Cancel)
	{	
		if(param == MenuCancel_ExitBack)
			ShowMenu_Main(client);
		g_bUseChat[client] = false;
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param, info, sizeof(info));
		int Item = StringToInt(info);
			
		switch(Item)
		{
			case 2:
			{
				ShowMenu_Target(client);
			}
			case 3:
			{
				char sText[256];
				if(MinCredits == 0) 
					if(MaxCredits == 0) 
						FormatEx(sText,sizeof sText,"Введите ставку в чат\n \n");
					else
						FormatEx(sText,sizeof sText,"Введите ставку в чат(до %i)\n \n",MaxCredits);
				else
					if(MaxCredits == 0) 
						FormatEx(sText,sizeof sText,"Введите ставку в чат(от %i)\n \n",MinCredits);
					else
						FormatEx(sText,sizeof sText,"Введите ставку в чат(от %i до %i)\n \n",MinCredits,MaxCredits);
				ShowMenu_BetMenu(client,sText,false);
			}
		}
	}
	return 0;
}

void ShowMenu_Target(int client)
{
	Menu menu = new Menu(Target_MenuHandler);
	menu.SetTitle("%s \nВыберите игрока:\n \n", GTITLE);

	char userid[10], name[64];
	for (int i = 1; i <= MaxClients; i++)
	{
		int iMin = GetCookieInt(i, CookieMinBet);
		int iMax = GetCookieInt(i, CookieMaxBet);
		if (IsValidClient(i, Options[client][bet]) && i != client && !ClientCookie[i] && (iMin <= Options[client][bet] <= iMax || iMax == 0))
		{
			IntToString(GetClientUserId(i), userid, sizeof(userid));
			GetClientName(i, name, sizeof(name));
			Format(name, sizeof(name), "%s (%i)", name, Shop_GetClientCredits(i));

			menu.AddItem(userid, name, Options[client][Started] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}
	}

	if (!menu.ItemCount)
	{
		menu.AddItem("", "Нет подходящих игроков", ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Target_MenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack)
	{
		char sText[128];
		FormatEx(sText,sizeof sText,"Ставка: %i кр.\n \n",Options[client][bet]);
		ShowMenu_BetMenu(client,sText,true);
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param, info, sizeof(info));

		Options[client][Target] = GetClientOfUserId(StringToInt(info));

		ShowMenu_Confirm(client);
	}
	return 0;
}

void ShowMenu_Confirm(int client)
{
	Menu menu = new Menu(Confirm_MenuHandler);
	menu.SetTitle("%s \nПодтверждение игры:\n \n", GTITLE);

	char buffer[128];

	Format(buffer, sizeof(buffer), "Игра: %s", g_eGames[Options[client][Game]].sName); menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	FormatEx(buffer, sizeof(buffer), "Игрок: %N", Options[client][Target]); menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	FormatEx(buffer, sizeof(buffer), "Ставка: %i (Комиссия %i%%)\n \n \n", Options[client][bet], Commission); menu.AddItem("", buffer, ITEMDRAW_DISABLED);

	menu.AddItem("", "Играть");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Confirm_MenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack)
	{
		ShowMenu_Target(client);
	}
	else if (action == MenuAction_Select)
	{
		if (param == 3)
		{
			new target = Options[client][Target];

			if (IsValidClient(target, Options[client][bet]) && !Options[target][Started] && !ClientCookie[target])
			{
				PrintToChat(client, "%s Предложение отправлено.", GPREFIX);
				ShowMenu_OfferToPlay(target, client);
			}
			else
			{
				PrintToChat(client, "%s Игрок недоступен.", GPREFIX);
			}
		}
	}
	return 0;
}

void ShowMenu_OfferToPlay(int client, int caller)
{
	Options[client][Game] =		Options[caller][Game];
	Options[client][bet] =		Options[caller][bet];
	Options[client][Target] =	caller;
	Options[client][Started] =	true;
	Options[caller][Started] =	true;

	Menu menu = new Menu(OfferToPlay_MenuHandler);
	menu.SetTitle("%s \nПоступило предложение:\n \n", GTITLE);

	char buffer[128];

	FormatEx(buffer, sizeof(buffer), "От: %N", caller); menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	FormatEx(buffer, sizeof(buffer), "Игра: %s", g_eGames[Options[caller][Game]].sName); menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	FormatEx(buffer, sizeof(buffer), "Ставка: %i (Комиссия %i%%)\n \n \n", Options[caller][bet], Commission); menu.AddItem("", buffer, ITEMDRAW_DISABLED);

	menu.AddItem("", "Принять");
	menu.AddItem("", "Отказаться");

	menu.ExitBackButton = false;
	menu.Display(client, ConfirmTime);
}

public int OfferToPlay_MenuHandler(Menu menu, MenuAction action, int client, int param)
{
	int caller;
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		caller = Options[client][Target];
	}

	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		ResetGame(client, caller);
		if(caller > 0 && IsClientInGame(caller) && !IsFakeClient(caller))
		{
			PrintToChat(caller, "%s Игрок \x04%N\x01 не принял предложение.", GPREFIX, client);
		}
	}
	else if (action == MenuAction_Select)
	{
		if (param == 3)
		{
			if(IsValidClient(client, Options[caller][bet]) && IsValidClient(caller, Options[caller][bet]))
			{
				PrintToChat(caller, "%s Игрок \x04%N\x01 принял предложение. Игра начнется через \x04%i\x01 секунд(ы).", GPREFIX, client, StartTime);
				CreateTimer(view_as<float>(StartTime), StartGame, client);
				TakeCredits(client,caller);
			}
			else
			{
				PrintToChat(client, "Ошибка! У кого то не хватает кредитов");
				PrintToChat(caller, "Ошибка! Игрок не смог принять. У кого то не хватает кредитов");
				ResetGame(client, caller);
			}
		}
		else
		{
			ResetGame(client, caller);
			PrintToChat(client, "%s Вы отказались от игры.", GPREFIX);
			PrintToChat(caller, "%s Игрок \x04%N\x01 отказался от игры.", GPREFIX, client);
		}
	}
	return 0;
}

void TakeCredits(int client1, int client2)
{
	int iBet = Options[client1][bet];
	Shop_TakeClientCredits(client1, iBet);
	Shop_TakeClientCredits(client2, iBet);
}

public int Native_ResetGame(Handle hPlugin, int iNumParams)
{
	ResetGame(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
	return 0;
}

void ResetGame(int client1, int client2 = 0, bool return_credits = false)
{
	if(return_credits && client2 > 0)
	{
		Shop_GiveClientCredits(client2,Options[client2][bet], IGNORE_FORWARD_HOOK);
		Shop_GiveClientCredits(client1,Options[client1][bet], IGNORE_FORWARD_HOOK);
	}
	Options[client1][Started] = false;
	Options[client2][Started] = false;
}

void ShowMenu_Rules(int client)
{
	Menu menu = new Menu(Rules_MenuHandler);
	menu.SetTitle("%s \n ∟Правила:\n \n", GTITLE);

	
	g_hKv.Rewind();
	char buffer[64];
	if(g_hKv.JumpToKey("Rules") && g_hKv.GotoFirstSubKey(false))
	{
		do
		{
			if(g_hKv.GetSectionName(buffer, sizeof(buffer)))
			{
				menu.AddItem(buffer, buffer);
			}
		}
		while(g_hKv.GotoNextKey());
	}

	if (!menu.ItemCount)
	{
		menu.AddItem("", "Нет доступных игр", ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Rules_MenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack)
	{
		ShowMenu_Main(client);
	}
	else if (action == MenuAction_Select)
	{
		char info[64], buffer[256];
		menu.GetItem(param, info, sizeof(info));
		Menu hMenu = new Menu(Rules_Handler);
		hMenu.SetTitle("%s \nПравила: %s\n \n", GTITLE, info);
		g_hKv.Rewind();
		if(g_hKv.JumpToKey("Rules") && g_hKv.JumpToKey(info) && g_hKv.GotoFirstSubKey(false))
		{
			do
			{
				g_hKv.GetString(NULL_STRING, buffer, sizeof(buffer));
				hMenu.AddItem("", buffer, ITEMDRAW_DISABLED);
			}
			while (g_hKv.GotoNextKey(false));
		}

		hMenu.ExitBackButton = true;
		hMenu.Display(client, 0);
	}
	return 0;
}

void ShowMenu_Settings(int client)
{
	Menu menu = new Menu(Settings_MenuHandler);
	menu.SetTitle("%s \n ∟Настройки:\n \n", GTITLE);

	char buffer[256], sValue[12];
	FormatEx(buffer, sizeof(buffer), "[%s] Отключить меню результатов в конце игры", ClientCookieResult[client] ? "✓" : "   ");
	menu.AddItem("", buffer);

	FormatEx(buffer, sizeof(buffer), "[%s] Игнорировать предложения об играх\n \n", ClientCookie[client] ? "✓" : "   ");
	menu.AddItem("", buffer);

	int iMin = GetCookieInt(client, CookieMinBet);
	IntToString(iMin, sValue, sizeof sValue);
	FormatEx(buffer, sizeof(buffer), "[%s] Минимальная ставка предложений", iMin ? sValue : "Не установлено");
	menu.AddItem("", buffer);
	
	int iMax = GetCookieInt(client, CookieMaxBet);
	IntToString(iMax, sValue, sizeof sValue);
	FormatEx(buffer, sizeof(buffer), "[%s] Максимальная ставка предложений", iMax ? sValue : "Не установлено");
	menu.AddItem("", buffer);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

stock int GetCookieInt(int client, Handle cookie) {
    char buffer[20];
    GetClientCookie(client, cookie, buffer, sizeof(buffer));
    return StringToInt(buffer);
}

public int Settings_MenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack)
	{
		ShowMenu_Main(client);
	}
	else if (action == MenuAction_Select)
	{
		char charBool[2][2] = {"0", "1"};

		switch(param)
		{
			case 0:
			{
				ClientCookieResult[client] ^= true;
				SetClientCookie(client, CookieResultMenu, charBool[view_as<int>(ClientCookieResult[client])]);
			}
			case 1:
			{
				ClientCookie[client] ^= true;
				SetClientCookie(client, CookieGames, charBool[view_as<int>(ClientCookie[client])]);
			}
			case 2:
			{
				PrintToChat(client, "%s Введите желаемый минимальный предел в чат (0 - Отключить)", GPREFIX);
				g_bSetMinBet[client] = true;
				ShowMenu_Settings(client);
			}
			case 3:
			{
				PrintToChat(client, "%s Введите желаемый максимальный предел в чат (0 - Отключить)", GPREFIX);
				g_bSetMaxBet[client] = true;
				ShowMenu_Settings(client);
			}
		}

		ShowMenu_Settings(client);
	}
	return 0;
}

public Action StartGame(Handle timer, any client)
{
	Call_StartFunction(g_eGames[Options[client][Game]].hPlugin, g_eGames[Options[client][Game]].fncCallback);
	Call_PushCell(client);
	Call_Finish();
	return Plugin_Continue;
}

int GetWinCredits(int iBet)
{
	return RoundToNearest(float(iBet) / 100 * (100 - Commission * 2));
}

public int Native_FinalGame(Handle hPlugin, int iNumParams)
{
	char sBuff1[256], sBuff2[256], sBuff3[64];
	GetNativeString(4, sBuff1, sizeof sBuff1);
	GetNativeString(3, sBuff2, sizeof sBuff2);
	GetNativeString(2, sBuff3, sizeof sBuff3);
	ResultGame(GetNativeCell(1), sBuff3, sBuff1, sBuff2, GetNativeCell(5));
	return 0;
}

void ResultGame(int client, char[] game_name, char[] buffer1, char[] buffer2, bool win = false)
{
	int iBet = Options[client][bet];
	int credits = GetWinCredits(iBet);

	if (win)
	{
		Shop_GiveClientCredits(client, iBet+credits, IGNORE_FORWARD_HOOK);
	}
	
	char buffer3[128];
	FormatEx(buffer3, sizeof(buffer3), "Вы %s %i кредитов", win ? "выиграли" : "проиграли", win ? iBet + credits : iBet);

	if(!ClientCookieResult[client])
	{
		Menu menu = new Menu(Result_MenuHandler);
		menu.SetTitle("%s:\n \n%s\n%s\n \n%s\n \n", game_name, buffer1, buffer2, buffer3);

		menu.AddItem("", "Закрыть");

		menu.ExitBackButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}

	PrintToChat(client, "%s %s.", GPREFIX, buffer3);
	ResetGame(client);
}

public int Result_MenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

int IsClientPlay(client)
{
	return Options[client][Started];
}

int GetClientEnemy(client)
{
	return Options[client][Target];
}
