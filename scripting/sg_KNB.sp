#include <shop_games>

public Plugin myinfo =
{
	name = "[Shop Core] KNB",
	author = "Monroe, Pisex",
	version = "1.0"
};

int Object[MAXPLAYERS+1];

char ObjectName[][] =
{
	"Камень",
	"Ножницы",
	"Бумага"
};

int Time[MAXPLAYERS+1];

#define NAME_GAME "Камень-Ножницы-Бумага"

public void OnPluginStart()
{
	if(SG_IsStart()) SG_OnStarted();
}

public void SG_OnStarted()
{
	SG_RegisterGame("knb", NAME_GAME, StartGame_KNB);
}

void StartGame_KNB(int client1)
{
	int client2 = SG_GetEnemy(client1);
	if (!SG_IsClientPlay(client2))
	{
		return;
	}

	ShowMenu_GameKNB(client1);
	ShowMenu_GameKNB(client2);

	if (!IsValidClient(client1) || !IsValidClient(client2))
	{
		SG_ResetGame(client1, client2);
	}
}

void ShowMenu_GameKNB(int client)
{
	CreateTimer(1.0, HudGame_KNB, client, TIMER_REPEAT);

	PrintToChat(client, "%s Игра началась.", GPREFIX);
	Object[client] = -1;
	Time[client] = SG_GetGameTime();

	Menu menu = new Menu(GameKNB_MenuHandler);
	menu.SetTitle("%s:\n \n", NAME_GAME);

	menu.AddItem("", "Камень");
	menu.AddItem("", "Ножницы");
	menu.AddItem("", "Бумага");

	menu.ExitButton = false;
	menu.Display(client, SG_GetGameTime());
}

public int GameKNB_MenuHandler(Menu menu, MenuAction action, int client1, int param)
{
	int client2;
	if (client1 > 0)
	{
		client2 = SG_GetEnemy(client1);
	}

	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (SG_IsClientPlay(client1))
		{
			SG_ResetGame(client1, client2);

			if (IsValidClient(client1))
			{
				PrintToChat(client1, "%s Вы не успели определиться. Игра закончена.", GPREFIX);
			}

			if (IsValidClient(client2))
			{
				PrintToChat(client2, "%s Игрок \x04%N\x01 не успел определиться. Игра закончена.", GPREFIX, client1);
			}
		}
	}
	else if (action == MenuAction_Select)
	{
		Object[client1] = param;
		Time[client1] = 0;
		PrintHintText(client1, "%s", ObjectName[param]);

		if (Object[client1] >= 0 && Object[client2] >= 0)
		{
			int winner = GetKNBWinner(client1, client2);

			if (winner == 0)
			{
				PrintToChat(client1, "%s Ничья. Играем еще раз.", GPREFIX);
				PrintToChat(client2, "%s Ничья. Играем еще раз.", GPREFIX);

				StartGame_KNB(client1);
			}
			else
			{
				char buffer1[128], buffer2[128];
				FormatEx(buffer1, sizeof(buffer1), "[%s] %N", ObjectName[Object[client1]], client1);
				FormatEx(buffer2, sizeof(buffer2), "[%s] %N", ObjectName[Object[client2]], client2);
				
				SG_FinalGame(winner, NAME_GAME, buffer2, buffer1, true);
				SG_FinalGame(SG_GetEnemy(winner), NAME_GAME, buffer2, buffer1);
			}
		}
		else
		{
			PrintToChat(client1, "%s Игрок \x04%N\x01 еще не определился.", GPREFIX, client2);
		}
	}
	return 0;
}

public Action HudGame_KNB(Handle timer, any client)
{
	if (!IsValidClient(client) || Time[client] <= 0)
	{
		return Plugin_Stop;
	}

	PrintHintText(client, "%i", Time[client]);
	Time[client] -= 1;

	return Plugin_Continue;
}

int GetKNBWinner(int client1, int client2)
{
	int c1 = Object[client1], c2 = Object[client2];
	if (c1 == 0 && c2 == 2 || c1 == 1 && c2 == 0 || c1 == 2 && c2 == 1)
	{
		return client2;
	}
	else if (c1 == 0 && c2 == 1 || c1 == 1 && c1 == 2 || c1 == 2 && c2 == 0)
	{
		return client1;
	}
	return 0;
}

