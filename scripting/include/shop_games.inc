#include <shop>

typedef GameCallBack = function void (int iClient);
native int SG_RegisterGame(char[] sName, char[] sDisplay, GameCallBack SG_CallbackGame);
native int SG_FinalGame(int iWinner, char[] buffer1, char[] buffer2, char[] buffer3, bool bWin = false);
native int SG_ResetGame(int iClient1, int iClient2, bool ReturnCredits = false);
native int SG_IsClientPlay(int iClient);
native int SG_GetEnemy(int iClient);
native bool SG_IsStart();
native int SG_GetGameTime();
forward void SG_OnStarted();

#define GPREFIX	"\x04[Games]\x01"
#define GTITLE	"Игры на двоих"

bool IsValidClient(int client, int credits = 0)
{
	return client > 0 ? IsClientInGame(client) && !IsFakeClient(client) ? Shop_GetClientCredits(client) >= credits ? true : false : false : false;
}