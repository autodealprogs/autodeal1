#include <Constants.au3>
#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <GuiEdit.au3>
#include <GuiButton.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>

;
; 维子创新同花顺自动交易助手ver1.0
; 解释器：AutoIt Version: 3.0
; 作者：吴继生
; 时间：2015.8.15
; 功能：检测同花顺预警触发的交易窗口处于激活状态时，发送“确认”按键
;

Global $tPoint = DllStructCreate($tagPOINT) ; Create a structure that defines the point to be checked.
Global $CodePosition[2], $NamePosition[2], $PricePosition[2], $NumberPosition[2], $ButtonPosition[2], $RefreshPosition[2]
Global $hWnd0, $BuyCtrlhWnd[6], $SellCtrlhWnd[6]
$BuyCtrlhWnd[0] = 0 ;用于判断是否获取交易系统控件句柄handle

; Create a GUI with various controls.
Global $ThsVersion="网上股票交易系统5.0"
Global $WinThsTitle="[TITLE:" & $ThsVersion & "]"    ;"[TITLE:网上股票交易系统5.0]"
Local $Width=650
Local $Height=80+20*10
Local $hGUI = GUICreate("维子创新同花顺自动交易助手ver1.0,微子创新软件工作室,2015.8", $Width, $Height)

; Create a button control.
Local $idStart0 = GUICtrlCreateButton("启动自动监控", $Width/2-85-60, 80+20*8, 85, 25)
Local $idBrowse0 = GUICtrlCreateButton("交易记录", $Width/2-45, 80+20*8, 85, 25)
Local $idClose0 = GUICtrlCreateButton("关闭", $Width/2+60, 80+20*8, 85, 25)
Local $idLabel0 = GUICtrlCreateLabel("", 10, 10, $Width-10, 20)
Local $idLabel1 = GUICtrlCreateLabel("", 10, 30, $Width-10, 20)
Local $idLabel2 = GUICtrlCreateLabel("", 10, 80+20*6, $Width-30, 20*2)
Local $idMyedit = GUICtrlCreateEdit("注意：本助手仅支持同花顺" & $ThsVersion & "! 交易指令如下：" & @CRLF, 10, 50, $Width-30, 20*7, $ES_AUTOVSCROLL + $WS_VSCROLL)

GUICtrlSetData($idLabel2, "据此投资，风险自负！本软件是否有效，与同花顺软件版本及交易设置等因素相关，请先在非交易时间试用并撤掉全部提交的交易！")

; Display the GUI.
GUISetState(@SW_SHOW, $hGUI)

Local $MyExistChk0 = 0

local $MyStart0 = 1    ;缺省启动监控
GUICtrlSetData($idLabel0, "正在监控中......")
GUICtrlSetData($idStart0, "关闭自动监控")

Local $isFirstRun = 1
Local $isRefreshed = 0
Local $hTimer0 = TimerInit()
Local $fDiff0, $fDiff1

Local $sText1, $sText2, $sText3, $sText_3, $sText8, $sText9, $sText10, $sText_10, $sStaticText1, $sStaticText8
Local $sBtnText1, $sBtnText2, $sBtnText3

Local $i0
local $i1
Local $str0

Local Const $sFilePath = @ScriptDir & "\thsauto.ini"
Local $sPassword = IniRead($sFilePath, "General", "账户密码", "")
If $sPassword == "" Then
   ;IniWrite($sFilePath, "General", "账户密码", "") ;账户密码不在ini文件中出现
EndIf

Local $MyDelayTime = IniRead($sFilePath, "General", "提交延时", "")
If $MyDelayTime == "" Then
   $MyDelayTime = "100"
   IniWrite($sFilePath, "General", "提交延时", $MyDelayTime)
EndIf

Local $ThsPath = IniRead($sFilePath, "General", "同花顺文件夹", "")
If $ThsPath == "" Then
   $ThsPath = "D:\Program Files (x86)\同花顺\"
   IniWrite($sFilePath, "General", "同花顺文件夹", $ThsPath)
EndIf

Local $NeedShutdown = IniRead($sFilePath, "General", "自动关机", "")
If $NeedShutdown == "" Then
   $NeedShutdown = "1"
   IniWrite($sFilePath, "General", "自动关机", $NeedShutdown)
EndIf

Local $RefreshInterval = IniRead($sFilePath, "General", "刷新间隔", "")
If $RefreshInterval == "" Then
   $RefreshInterval = "1" ;间隔1min刷新交易窗口
   IniWrite($sFilePath, "General", "刷新间隔", $RefreshInterval)
EndIf

ReadCtrlPosition() ;从ini文件中读入买入卖出控件的坐标

Local Const $sMyFilePath0 = @ScriptDir & "\交易记录.txt"
Local $hMyFileOpen
If FileExists($sMyFilePath0) == 1 Then
   $hMyFileOpen = FileOpen($sMyFilePath0, $FO_READ + $FO_APPEND)
Else
   $hMyFileOpen = FileOpen($sMyFilePath0, $FO_READ + $FO_OVERWRITE)
EndIf

Local $MyCount = 1
$str0 = @YEAR & "."& @MON & "." & @MDAY & @CRLF
GUICtrlSetData($idMyedit, $str0, $MyCount)
If $hMyFileOpen <> -1 Then
   FileWrite($hMyFileOpen, $str0)
EndIf

Local $StartHour = @HOUR, $StartMin = @MIN
local $isShutDown =0

;检查同花顺行情软件是否在运行，Retrieve a list of window handles.
Local $isThsRuning = 0
Local $aList = WinList()
;Loop through the array displaying only visable windows with a title.
For $i = 1 To $aList[0][0]
   If $aList[$i][0] <> "" And BitAND(WinGetState($aList[$i][1]), 2) Then
	  If StringInStr($aList[$i][0], "同花顺(") == 1 Then
		 $isThsRuning = 1
	  EndIf
   EndIf
Next
If $isThsRuning == 0 Then
   ;运行同花顺行情软件，并自动提交登录......
   GUICtrlSetData($idLabel1, "正在启动同花顺行情软件，交易系统需在行情软件中人工启动......")
   Run($ThsPath & "hexin.exe", $ThsPath)
   WinWaitActive("[TITLE:登录到全部行情主站]", "", 2)

   $fDiff0 = TimerDiff($hTimer0)
   $fDiff1 = $fDiff0
   While ($fDiff1 - $fDiff0) <= 8000
	  $str0 = ControlGetText("[TITLE:登录到全部行情主站]", "", "[CLASS:Edit; INSTANCE:1]") ;账户账号
	  if $str0 <> "" Then
		 Sleep(300)
		 ControlClick ("[TITLE:登录到全部行情主站]","","[Class:Button; INSTANCE:1]","Left")
		 ExitLoop
	  EndIf
	  $fDiff1 = TimerDiff($hTimer0)
   WEnd
EndIf

; Loop until the user exits.
While 1
   Switch GUIGetMsg()
	  Case $GUI_EVENT_CLOSE, $idClose0
		 $MyStart0 = 0
		 ExitLoop

	  Case $idStart0
		 If $MyStart0 <> 1 Then
			$MyStart0 = 1
			GUICtrlSetData($idLabel0, "正在监控中......")
			GUICtrlSetData($idStart0, "关闭自动监控")
		 Else
			$MyStart0 = 0
			$MyExistChk0 = 0
			GUICtrlSetData($idLabel0, "监控已取消！")
			GUICtrlSetData($idLabel1, "")
			GUICtrlSetData($idStart0, "启动自动监控")
		 EndIf
	  Case $idBrowse0
		 Run("Notepad " & $sMyFilePath0)
   EndSwitch

   If $MyStart0 == 1 Then
	  If WinExists($WinThsTitle) Then
		 $hWnd0 = WinGetHandle($WinThsTitle)
		 ; Retrieve the state of the Notepad window using the handle returned by WinWait.
		 Local $iState = WinGetState($hWnd0)
		 If BitAND($iState, 2) Or BitAND($iState, 16) Then ;$WIN_STATE_VISIBLE (2) = Window is visible，即交易系统启动，并已完成登录
			If $MyExistChk0<>1 Then ;交易系统刚刚启动
			   GUICtrlSetData($idLabel1, "同花顺" & $ThsVersion & "已启动，正在匹配中......")

			   $fDiff0 = TimerDiff($hTimer0)
			   $fDiff1 = $fDiff0
			   While ($fDiff1 - $fDiff0) <= 3000
				  MyVerify() ;清除可能弹出的确认窗口
				  GetBuySellCtrlhWnd() ;激活买入卖出界面，根据坐标获取控件handle
				  If ($BuyCtrlhWnd[0]== 0) Or ($BuyCtrlhWnd[1]== 0) Or ($BuyCtrlhWnd[2]== 0) Or ($BuyCtrlhWnd[3]== 0) Or ($SellCtrlhWnd[0]== 0) Or ($SellCtrlhWnd[1]== 0) Or ($SellCtrlhWnd[2]== 0) Or ($SellCtrlhWnd[3]== 0) Then
					 WinSetState($WinThsTitle,"",@SW_MAXIMIZE)
					 If BitAND(WinGetState($hWnd0), 16) Then ;如果还是最小化，则可能是锁屏状态，需要Enter键激活密码输入窗口
						Send("{ENTER}")
					 EndIf
					 MyVerify() ;清除可能弹出的确认窗口
				  Else
					 $MyExistChk0 = 1 ;匹配成功
					 GUICtrlSetData($idLabel1, "与同花顺" & $ThsVersion & "匹配成功，正处于监控中！")
					 ExitLoop
				  EndIf

				  $fDiff1 = TimerDiff($hTimer0)
			   WEnd
			EndIf

			If $MyExistChk0 == 1 Then ;匹配成功......
			   MyRefresh() ;间隔5min刷新交易窗口
			   MyCheck() ;判断交易系统处于激活状态，则处理交易......
			EndIf
		 ElseIf $MyExistChk0<>2 Then ;交易系统正在登录
			   $MyExistChk0 = 2
			   GUICtrlSetData($idLabel1, "同花顺" & $ThsVersion & "，用户正在登陆，或者行情/交易软件都处于最小化状态-监控无效！")
			   WinWaitActive("[TITLE:用户登录]", "", 5)

			   If $sPassword <> "" Then
				  $fDiff0 = TimerDiff($hTimer0)
				  $fDiff1 = $fDiff0
				  While ($fDiff1 - $fDiff0) <= 5000
					 $str0 = ControlGetText("[TITLE:用户登录]", "", "[CLASS:Edit; INSTANCE:1]") ;账户账号
					 if $str0 <> "" Then
						Sleep(500)
						ControlSetText("[TITLE:用户登录]", "", "[CLASS:Edit; INSTANCE:2]", $sPassword) ;填入账户密码
						ControlFocus("[TITLE:用户登录]", "", "[CLASS:Edit; INSTANCE:7]")
						ExitLoop
					 EndIf
					 $fDiff1 = TimerDiff($hTimer0)
				  WEnd
			   EndIf
		 EndIf
	  Else
		 If $MyExistChk0<>3 Then ;交易系统已关闭
			$MyExistChk0 = 3
			GUICtrlSetData($idLabel1, "同花顺" & $ThsVersion & "没有启动，监控无效！")
		 EndIf
	  EndIf
   EndIf

   If $isFirstRun == 1 Then ;第一次运行最小化主窗口
	  $fDiff0 = TimerDiff($hTimer0)
	  If $fDiff0>2000 Then
		 $isFirstRun = 0
		 WinSetState($hGUI,"",@SW_MINIMIZE )
	  EndIf
   EndIf

   If ($NeedShutdown == "1") And ((@HOUR - $StartHour + (@MIN - $StartMin)) / 60. >= 1) And (@HOUR + @MIN / 60. >= 15.5) And ($StartHour < 15) Then ;持续运行2小时且>=下午3:30，则自动关机
	  $isShutDown = 1
	  ExitLoop
   EndIf

WEnd

FileClose($hMyFileOpen)

; Delete the previous GUI and all controls.
GUIDelete($hGUI)

If $isShutDown == 1 then
   Shutdown( BitOR($SD_SHUTDOWN, $SD_POWERDOWN))
EndIf

;Finished!

Func MyCheck()
   MyVerify() ;清除可能弹出的确认窗口

   If $BuyCtrlhWnd[0] == 0 Then
	  Return
   EndIf

   If WinActive($WinThsTitle) Then
	  $sText3 = _GUICtrlEdit_GetText($BuyCtrlhWnd[3]) ;买入数量
	  $sText10 = _GUICtrlEdit_GetText($SellCtrlhWnd[3]) ;卖出数量

	  If ($sText3 == "") And ($sText10 == "") Then
		 Return
	  EndIf

	  $sText_3 = _GUICtrlEdit_GetText($BuyCtrlhWnd[3]) ;买入数量
	  $sText_10 = _GUICtrlEdit_GetText($SellCtrlhWnd[3]) ;卖出数量

	  If ($sText3 <> "") and ($sText3 == $sText_3) Then ;买入条件判断，同花顺有时先填写数量，当证券名称出现时，数量将被自动清除
		 $fDiff0 = TimerDiff($hTimer0)
		 $fDiff1 = $fDiff0
		 While ($fDiff1 - $fDiff0) <= 2000
			$sText1 = _GUICtrlEdit_GetText($BuyCtrlhWnd[0])  ;买入代码
			$sStaticText1 = _GUICtrlEdit_GetText($BuyCtrlhWnd[1])  ;买入名称
			$sText2 = _GUICtrlEdit_GetText($BuyCtrlhWnd[2]) ;买入价格

			MyVerify() ;清除可能弹出的确认窗口

			If ($sText1 <> "") and ($sStaticText1 <> "") And ($sText2 <> "") Then ;买入......
			   $MyCount = $MyCount + 1;
			   $str0 = @HOUR & ":" & @MIN & ":" & @SEC & "	买入:	"& $sText1 & "	" & $sStaticText1 & "	" & $sText2 & "	"  & $sText3 & @CRLF
			   GUICtrlSetData($idMyedit, $str0, $MyCount)
			   If $hMyFileOpen <> -1 Then
				  FileWrite($hMyFileOpen, $str0)
			   EndIf

			   Sleep($MyDelayTime)

			   _GUICtrlEdit_SetText($BuyCtrlhWnd[3], $sText3) ;买入数量需要重新填入，因为可能在填写代码时被清除了
			   ;_GUICtrlButton_Click($BuyCtrlhWnd[4]) ;买入，该指令在交易系统弹出确认窗口时，本软件处于暂停状态，必须人工关闭确认窗口后才继续执行
			   ControlClick($WinThsTitle,"",$BuyCtrlhWnd[4]) ;买入

			   Sleep($MyDelayTime)
			   MyVerify() ;清除可能弹出的确认窗口

			   _GUICtrlEdit_SetText($BuyCtrlhWnd[3], "") ;清除买入数量，避免重复买入

			   ExitLoop
			EndIf

			$fDiff1 = TimerDiff($hTimer0)
		 WEnd
	  ElseIf ($sText10 <> "") And ($sText10 == $sText_10) Then ;卖出......
		 $fDiff0 = TimerDiff($hTimer0)
		 $fDiff1 = $fDiff0
		 While ($fDiff1 - $fDiff0) <= 2000
			$sText8 = _GUICtrlEdit_GetText($SellCtrlhWnd[0]) ;卖出代码
			$sStaticText8 = _GUICtrlEdit_GetText($SellCtrlhWnd[1]) ;卖出名称
			$sText9 = _GUICtrlEdit_GetText($SellCtrlhWnd[2])  ;卖出价格

			MyVerify() ;清除可能弹出的确认窗口

			If ($sText8 <> "") and ($sStaticText8 <> "") And ($sText9 <> "") Then ;卖出......
			   $MyCount = $MyCount + 1;
			   $str0 = @HOUR & ":" & @MIN & ":" & @SEC & "	卖出:	"& $sText8 & "	" & $sStaticText8 & "	" & $sText9 & "	"  & $sText10 & @CRLF
			   GUICtrlSetData($idMyedit, $str0, $MyCount)
			   If $hMyFileOpen <> -1 Then
				  FileWrite($hMyFileOpen, $str0)
			   EndIf

			   Sleep($MyDelayTime)

			   _GUICtrlEdit_SetText($SellCtrlhWnd[3], $sText10) ;卖出数量需要重新填入，因为可能在填写代码时被清除了
			   ;_GUICtrlButton_Click($SellCtrlhWnd[4]) ;卖出，该指令在交易系统弹出确认窗口时，本软件处于暂停状态，必须人工关闭确认窗口后才继续执行
			   ControlClick($WinThsTitle,"",$SellCtrlhWnd[4]) ;卖出

			   Sleep($MyDelayTime)
			   MyVerify() ;清除可能弹出的确认窗口

			   _GUICtrlEdit_SetText($SellCtrlhWnd[3], "") ;清除卖出数量，避免重复卖出

			   ExitLoop
			EndIf

			$fDiff1 = TimerDiff($hTimer0)
		 WEnd
	  EndIf
   EndIf
EndFunc

Func MyVerify() ;清除可能弹出的确认窗口
   ;检查最新启动的窗口是否需要关闭
   $hWnd0 = _WinAPI_GetWindow (0, $GW_HWNDLAST)
   WinActivate($hWnd0);ControlClick通常对当前激活窗口有效

   $Str0 = ControlGetText("[ACTIVE]", "", "[CLASS:Static; INSTANCE:1]")
   If $Str0 == "请输入您的交易密码" Then
	  ControlSetText("[ACTIVE]", "", "[CLASS:Edit; INSTANCE:1]", $sPassword) ;填入账户密码
   ElseIf (WinGetTitle("[ACTIVE]") <> "") Or ($Str0 == "系统设置") Or ($Str0 == "高级选项") Then ;交易系统在交易时经常弹出一些需要确认的窗口，这些窗口没有Title
	  Return
   EndIf

   $Str0 = ControlGetText("[ACTIVE]", "", "[CLASS:Button; INSTANCE:1]")
   If ($str0 == "是(&Y)")  Or ($str0 == "确定") Then
	  ControlClick ("[ACTIVE]","","[Class:Button; INSTANCE:1]","Left")
   EndIf
EndFunc

Func MyRefresh() ;间隔1min刷新交易窗口
   If WinExists($WinThsTitle) == 0 Then
	  Return
   EndIf

   $i0 = @MIN + @SEC/60.
   $i1 = $i0 - Int($i0 / $RefreshInterval) * $RefreshInterval
   If ($i1 >= 0) And ($i1 < $RefreshInterval/2) Then
	  If $isRefreshed == 0 Then ;每间隔1min仅刷新一次
		 $isRefreshed = 1
		 WinActivate($WinThsTitle)
		 If BitAND(WinGetState($WinThsTitle), 16) Then ;如果还是最小化，则可能是锁屏状态，需要Enter键激活密码输入窗口
			Send("{ENTER}")
			Sleep($MyDelayTime)
		 EndIf

		 MyVerify() ;清除可能弹出的确认窗口
		 ;_GUICtrlButton_Click($BuyCtrlhWnd[5]) ;刷新
		 ;_GUICtrlButton_Click($SellCtrlhWnd[5]) ;刷新
		 ControlClick($WinThsTitle,"",$BuyCtrlhWnd[5]) ;刷新
	  EndIf
   Else ;下一个1min再刷新
	  $isRefreshed = 0
   EndIf
EndFunc

Func ReadCtrlPosition()
   $CodePosition[0] = IniRead($sFilePath, "CtrlPosotion", "代码X", "")
   If $CodePosition[0] == "" Then
	  $CodePosition[0] = "256"
	  IniWrite($sFilePath, "CtrlPosotion", "代码X", $CodePosition[0])
   EndIf
   $CodePosition[1] = IniRead($sFilePath, "CtrlPosotion", "代码Y", "")
   If $CodePosition[1] == "" Then
	  $CodePosition[1] = "88"
	  IniWrite($sFilePath, "CtrlPosotion", "代码Y", $CodePosition[1])
   EndIf

   $NamePosition[0] = IniRead($sFilePath, "CtrlPosotion", "名称X", "")
   If $NamePosition[0] == "" Then
	  $NamePosition[0] = "256"
	  IniWrite($sFilePath, "CtrlPosotion", "名称X", $NamePosition[0])
   EndIf
   $NamePosition[1] = IniRead($sFilePath, "CtrlPosotion", "名称Y", "")
   If $NamePosition[1] == "" Then
	  $NamePosition[1] = "106"
	  IniWrite($sFilePath, "CtrlPosotion", "名称Y", $NamePosition[1])
   EndIf

   $PricePosition[0] = IniRead($sFilePath, "CtrlPosotion", "价格X", "")
   If $PricePosition[0] == "" Then
	  $PricePosition[0] = "256"
	  IniWrite($sFilePath, "CtrlPosotion", "价格X", $PricePosition[0])
   EndIf
   $PricePosition[1] = IniRead($sFilePath, "CtrlPosotion", "价格Y", "")
   If $PricePosition[1] == "" Then
	  $PricePosition[1] = "124"
	  IniWrite($sFilePath, "CtrlPosotion", "价格Y", $PricePosition[1])
   EndIf

   $NumberPosition[0] = IniRead($sFilePath, "CtrlPosotion", "数量X", "")
   If $NumberPosition[0] == "" Then
	  $NumberPosition[0] = "256"
	  IniWrite($sFilePath, "CtrlPosotion", "数量X", $NumberPosition[0])
   EndIf
   $NumberPosition[1] = IniRead($sFilePath, "CtrlPosotion", "数量Y", "")
   If $NumberPosition[1] == "" Then
	  $NumberPosition[1] = "160"
	  IniWrite($sFilePath, "CtrlPosotion", "数量Y", $NumberPosition[1])
   EndIf

   $ButtonPosition[0] = IniRead($sFilePath, "CtrlPosotion", "确认X", "")
   If $ButtonPosition[0] == "" Then
	  $ButtonPosition[0] = "280"
	  IniWrite($sFilePath, "CtrlPosotion", "确认X", $ButtonPosition[0])
   EndIf
   $ButtonPosition[1] = IniRead($sFilePath, "CtrlPosotion", "确认Y", "")
   If $ButtonPosition[1] == "" Then
	  $ButtonPosition[1] = "184"
	  IniWrite($sFilePath, "CtrlPosotion", "确认Y", $ButtonPosition[1])
   EndIf

   $RefreshPosition[0] = IniRead($sFilePath, "CtrlPosotion", "刷新X", "")
   If $RefreshPosition[0] == "" Then
	  $RefreshPosition[0] = "383"
	  IniWrite($sFilePath, "CtrlPosotion", "刷新X", $RefreshPosition[0])
   EndIf
   $RefreshPosition[1] = IniRead($sFilePath, "CtrlPosotion", "刷新Y", "")
   If $RefreshPosition[1] == "" Then
	  $RefreshPosition[1] = "273"
	  IniWrite($sFilePath, "CtrlPosotion", "刷新Y", $RefreshPosition[1])
   EndIf
EndFunc

Func GetBuySellCtrlhWnd()
   WinActivate($WinThsTitle)
   $hWnd0 = WinGetHandle($WinThsTitle) ;在GetlCtrlhWnd()中用到

   $fDiff0 = TimerDiff($hTimer0)
   $fDiff1 = $fDiff0
   While ($fDiff1 - $fDiff0) <= 1000
	  Send("{F1}")

	  $BuyCtrlhWnd[0] = GetlCtrlhWnd($CodePosition[0], $CodePosition[1])
	  $BuyCtrlhWnd[1] = GetlCtrlhWnd($NamePosition[0], $NamePosition[1])
	  $BuyCtrlhWnd[2] = GetlCtrlhWnd($PricePosition[0], $PricePosition[1])
	  $BuyCtrlhWnd[3] = GetlCtrlhWnd($NumberPosition[0], $NumberPosition[1])
	  $BuyCtrlhWnd[4] = GetlCtrlhWnd($ButtonPosition[0], $ButtonPosition[1])
	  $BuyCtrlhWnd[5] = GetlCtrlhWnd($RefreshPosition[0], $RefreshPosition[1])

	  $sBtnText1 = _GUICtrlButton_GetText($BuyCtrlhWnd[4]) ;买入按钮
	  $sBtnText3 = _WinAPI_GetClassName ($BuyCtrlhWnd[5]) ;刷新按钮
	  If ($sBtnText1 == "买入[B]") And ($sBtnText3 == "Button")  Then ;获得的不是买入和卖出页面的控件句柄，需要重新获取
		 ExitLoop
	  EndIf
	  $fDiff1 = TimerDiff($hTimer0)
   WEnd

   If $sBtnText1 == "买入[B]"  Then ;获得的不是买入和卖出页面的控件句柄，需要重新获取
	  $fDiff0 = TimerDiff($hTimer0)
	  $fDiff1 = $fDiff0
	  While ($fDiff1 - $fDiff0) <= 1000
		 Send("{F2}")

		 $SellCtrlhWnd[0] = GetlCtrlhWnd($CodePosition[0], $CodePosition[1])
		 $SellCtrlhWnd[1] = GetlCtrlhWnd($NamePosition[0], $NamePosition[1])
		 $SellCtrlhWnd[2] = GetlCtrlhWnd($PricePosition[0], $PricePosition[1])
		 $SellCtrlhWnd[3] = GetlCtrlhWnd($NumberPosition[0], $NumberPosition[1])
		 $SellCtrlhWnd[4] = GetlCtrlhWnd($ButtonPosition[0], $ButtonPosition[1])
		 $SellCtrlhWnd[5] = GetlCtrlhWnd($RefreshPosition[0], $RefreshPosition[1])

		 $sBtnText2 = _GUICtrlButton_GetText($SellCtrlhWnd[4]) ;卖出按钮
		 $sBtnText3 = _WinAPI_GetClassName($SellCtrlhWnd[5]) ;刷新按钮
		 If ($sBtnText2 == "卖出[S]") And ($sBtnText3 == "Button")  Then ;获得的不是买入和卖出页面的控件句柄，需要重新获取
			ExitLoop
		 EndIf
		 $fDiff1 = TimerDiff($hTimer0)
	  WEnd
   EndIf

   Send("{F1}")

   If $sBtnText1 <> "买入[B]" Or $sBtnText2 <> "卖出[S]" Then ;获得的不是买入和卖出页面的控件句柄，需要重新获取
	  $BuyCtrlhWnd[0] = 0
   EndIf
EndFunc

Func GetlCtrlhWnd($x, $y)
   Position($x, $y)
   _WinAPI_ClientToScreen($hWnd0, $tPoint)

   Return(_WinAPI_WindowFromPoint($tPoint)) ; Retrieve the window handle.
EndFunc

Func Position($x, $y)
    DllStructSetData($tPoint, "x", $x+2)
    DllStructSetData($tPoint, "y", $y+2)
EndFunc   ;==>Position

