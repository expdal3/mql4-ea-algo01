//+------------------------------------------------------------------+
//|                                                 TradeUtility.mqh |
//|                                         Copyright 2019, Andre Le |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, Andre Le"
#property link      "https://www.mql5.com"
#property version "2.10"
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
 //+==================TRADE SYSTEM MANAGEMENT========================================+
 //| 1. TimeLapseClose() module: used to closed pending order being opened after 2H  |
 //| 2. PartialClose() module: partial close losing trades                           |
 //|
 //+=================================================================================+
#include <TextBoxCornerPkg.mqh>

input string _TRADEUTILITY____ = "---Parameters for Trade Utility Programmes---";

extern bool UseMoveToBreakeven=true;
extern int  WhenToMoveToBE=50; //WhenToMoveToBE
extern int  PipsToLockIn=10; //BreakEven-LockedInPips
int defaultTP =500;
int defaultSL = 300;

//=====Trailing stop variables ==================
input string TradeUtility1 = "----Parameters for Trailing Stops---";
extern bool UseTrailingStop = true;
extern int  WhenToTrail=60; //TrailStop: trigger pips in profit to trail
extern int  TrailAmount=50; //TrailStop: pips amt to trail
extern bool UseCandleTrail=false; //Using CandleTrailingStop
extern bool UseATRtoTrail = false; //Trail pips amt base on ATR

enum LotSizeFactorEnum 
  {
   Standard,     // Standard Lot 
   Mini,     // Mini Lot
   Micro,     // Micro Lot
  };
input LotSizeFactorEnum LotSizeFactor=Mini;
double _LotSizeFactor;

//====Set-up Signal variables ============
input string TradeUtility2 = "---Parameters for set up conditions---";
extern int PadAmountTrailSL=100; //buffer no.ofpips where trailing stop won't move if price still within the zone, =0 if use iHighest or iLowest
extern int PadAmount_Entry=3; //buffer zone around entry price
extern int SuppResis_Buffer=10; //buffer zone Support and Resistance line
extern int MAChk_Buffer=10; //buffer zone for higher timeframe MA
extern int CandlesBack=5; //look back how many candle for candle trail stop (include the candle [0])
extern int ATR_TF=60;

//=======Risk management - positions management variables ==========

//--setting vars for RSIReversalChkTimeFrame and SuppResisChek
input string s4b = "---RSIReversalChkTimeFrame and SuppResisChek---";

extern ENUM_TIMEFRAMES RSIReversalChkTimeFrame=PERIOD_H4; //setting timeframe for RSI OverboughtOversold Check
extern int ReversalTradePip=200; //setting number of pips for ReversalTrade
extern int rsiLo = 40;
extern int rsiHi = 65;

extern int NoBUYActiveTrade=2;
extern int NoSELLActiveTrade=1;

extern int NoBUYPendingTrade=1;
extern int NoSELLPendingTrade=1;
extern int TimeLapseCloseDuration=4;
//+--------------SuppResisChk
extern ENUM_TIMEFRAMES SuppResisChkTF1=PERIOD_M30;
extern ENUM_TIMEFRAMES SuppResisChkTF2=PERIOD_H1;
extern int inpSRlookback1=100; 
extern int inpSRlookback2=100;

string SuppResisPath = "CustomIndi\\5MTF_SR";
double SuppResisArray[4];


double maxSupp;
double maxResis;
double minSupp;
double minResis;


//--Settings for PartiallyClose function
input string s6 = "Positions management 2: Partially close trades---";
extern double PartialClosePct = 0.5;
extern int PartialCloseMinPip = 65;
extern double PartialCloseSize = 0.5;

//------Settings for AvoidNewsChk function
extern bool AvoidNews=true;
extern int MinimumImpact=3; //Check high impact news (rank 3) only
extern int MinsBeforeNews=30;
extern int MinsAfterNews=30; //number of minutes after the news
extern string FFCalPath = "CustomIndi\\CalendarFX-I-A16_18.11.19";



int ObjBuyCounter = 0, ObjSellCounter = 0;
double pips = Point;
extern int MagicNumber = 91234;
//+------------------------------------------------------------------+
//| 1.Close pending tickes if already opened for awhile              |
//+------------------------------------------------------------------+
 int TimeLapseClose(string sym) //<<-- function for trailing stop base on number of pips moved
{
   //checking how many open orders on the current chart and loop through them until 0
   int maxDuration = TimeLapseCloseDuration * 60 * 60; //= 2 Hours or 120 mins
   for(int b=OrdersTotal()-1; b >=0; b-- )// loop thru opening order
   {
      if(OrderSelect(b,SELECT_BY_POS,MODE_TRADES)) //select the order 
      {
         if(OrderMagicNumber()==MagicNumber && OrderSymbol()==sym && 
         (OrderType()==OP_BUYLIMIT || OrderType()==OP_SELLLIMIT)) //Only close limit orders;
               {
              int duration = TimeCurrent() - OrderOpenTime(); //check duration of Current time versus the Current selected order's opening time
               if (duration >= maxDuration)
                  {
                  
                   OrderDelete(OrderTicket(),Magenta);
                   Print("[Timelapse] Limit order Pos #", b, "ticket: ", OrderTicket()," is closed for being inactive too long");
                  }
              }
        }
      else Print("OrderSelect returned error of ",GetLastError());   
   }
   return(0);
} 
//+------------------------------------------------------------------+
//| 2.Partially close tickes                                         |
//+------------------------------------------------------------------+

  void PartialClose(string sym)
   {
   double sAsk = MarketInfo(sym,MODE_ASK); double sBid = MarketInfo(sym,MODE_BID);
     if(OrdersTotal()) //<-- if there is a order opened
    {
     for(int s=OrdersTotal()-1; s >=0; s-- ) //reduce by one
      {
      if(OrderSelect(s,SELECT_BY_POS,MODE_TRADES)) 
       if(OrderMagicNumber()==MagicNumber) //check if the selected order was opened by the EA base on the magic number
         {
         double oop=OrderOpenPrice(); //get the Order's Opened Price
         double otp=OrderTakeProfit();
         double osl=OrderStopLoss();
         //Print("otp is: ", MathMin(OrderTakeProfit(),OrderOpenPrice()-defaultTP*pips);
         //Print("osl is: ", MathMax(OrderStopLoss(),OrderOpenPrice()+defaultSL*pips);
           
         //if(!OrderTakeProfit()) otp = OrderOpenPrice()+defaultTP*pips;
         double olots = OrderLots();
         int oticket = OrderTicket(); //get the orderticket -- index generated by OrderSelect
         int otype= OrderType();
        /*
         switch(OrderType())
         {
            case OP_BUY:
              otp=MathMax(OrderTakeProfit(),OrderOpenPrice()+defaultTP*pips); 
              osl=MathMax(OrderStopLoss(),OrderOpenPrice()-defaultSL*pips);
               break;
           case OP_SELL:
              otp=MathMin(OrderTakeProfit(),OrderOpenPrice()-defaultTP*pips);
              osl=MathMin(OrderStopLoss(),OrderOpenPrice()+defaultSL*pips);
              break;
         }
         */
         //if(lots = LotSize)
        // if(otype == OP_BUY && (((Bid-oop)/(otp-oop))>=PartialClosePct || (Bid-oop)*pips>=PartialCloseMinPip))
        // if(otype == OP_SELL && (((oop-Ask)/(oop-otp))>=PartialClosePct || (Bid-oop)*pips>=PartialCloseMinPip))
         string logString_1 = "[PartialClose] Current Partially Close trade: " + StringFind(OrderComment(),"#",0);
         string logString_2 = "[PartialClose] Ask price :" + sAsk + "OOP: " + oop + "OTP: " + otp + " , OSL: "+  osl;
         string logString_3 = "[PartialClose] Order tic " + oticket + "'s profit % is " + (oop-sAsk)/(oop-osl)*100 + "%";
         if(StringFind(OrderComment(),"#",0)<0) //check if that the current order has not been Closed once
         {
            //if(otype == OP_BUY && (((Bid-oop)/(otp-oop))>PartialClosePct || (Bid-oop)>PartialCloseMinPip*pips))
            if(otype == OP_BUY && oop>sBid && (((oop-sBid)/(oop-osl))>PartialClosePct || (oop-sBid)>PartialCloseMinPip*pips)) //check how % loss

            {
               if(!OrderClose(oticket,NormalizeDouble(olots*PartialCloseSize,2),sBid,30, clrRed))Print("failure to close order");
                  else  OrderClose(oticket,NormalizeDouble(olots*PartialCloseSize,2),sBid,30, clrRed);
                  Print(logString_1);
                  Print(logString_2);
                  Print(logString_3);
            }
         //else if(otype == OP_SELL && (((oop-Ask)/(otp-oop))>=PartialClosePct || (oop-Ask)>PartialCloseMinPip*pips))
         else if(otype == OP_SELL && sAsk>oop && (((sAsk-oop)/(osl-oop))>PartialClosePct || (sAsk-oop)>PartialCloseMinPip*pips))
            {
               if(!OrderClose(oticket,NormalizeDouble(olots*PartialCloseSize,2),sAsk,30, clrRed))Print("failure to close order");
                  else OrderClose(oticket,NormalizeDouble(olots*PartialCloseSize,2),sAsk,30, clrRed);
                  Print(logString_1);
                  Print(logString_2);
                  Print(logString_3);

            }
           } //end of if(StringFind( ....
       } //end of for(int s=OrdersTotal()...
       } 
      }  //end of if(OrdersTotal())....
         return;
      } 

//+------------------------------------------------------------------+
//| 3.Move to Break Even function                                    |
//+------------------------------------------------------------------+
void MoveToBreakeven(string sym)//<<-- function for moving to break even
{
   double sAsk = MarketInfo(sym,MODE_ASK); double sBid = MarketInfo(sym,MODE_BID);

   //checking how many open orders on the current chart and loop through them until 0
   //BUY ORDERS
   int WhenToMoveToBE_ = PipsToLockIn;
   if(UseATRtoTrail)
   {
   WhenToMoveToBE_=iATR(sym,ATR_TF,20,0)*10000 ; //<-- this set the number of pips (points) price has crossed above/below Entry
   }
   else WhenToMoveToBE_=WhenToMoveToBE;
   for(int b=OrdersTotal()-1; b >=0; b-- /*reduce by one*/) 
   {
   if(OrderSelect(b,SELECT_BY_POS,MODE_TRADES)) //select the order 
      if(OrderMagicNumber()==MagicNumber) //check if the selected order was opened by the EA base on the magic number
         //Note: the above line can be OrderMagicNumber()!=MagicNumber) continue; or break; to skip to next loop or break out loop
        if(OrderSymbol()==sym)
         if(OrderType()==OP_BUY) //check if it is a open buy order (exit loop for limit order)
      //Alternative filter: if(!OrderSelect(b,SELECT_BY_POS,MODE_TRADES)||OrderMagicNumber()!=MagicNumber||OrderType()!=OP_BUY) continue;
      //Check if the order is in profit of 100pips
            if(sBid-OrderOpenPrice()>WhenToMoveToBE_*pips)  
               if(OrderOpenPrice()>OrderStopLoss())
                  OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()+(PipsToLockIn*pips),OrderTakeProfit(),0,clrNONE);
                  return;
                  //Print("WhenToMoveToBE: ", WhenToMoveToBE_, "Current Bid - Entry = ", Bid-OrderOpenPrice());

                  //UseTrailingStop=true;
   }
   //SELL ORDERS
   for(int s=OrdersTotal()-1; s >=0; s-- /*reduce by one*/) 
   {
   if(OrderSelect(s,SELECT_BY_POS,MODE_TRADES)) //select the order
      if(OrderMagicNumber()==MagicNumber) //check if the order is opened by the EA
         //Note: the above line can be OrderMagicNumber()!=MagicNumber) continue; or break; to skip to next loop or break out loop
        if(OrderSymbol()==sym)
         if(OrderType()==OP_SELL) //check if it is a open buy order (exit loop for limit order)
      //Alternative filter: if(!OrderSelect(b,SELECT_BY_POS,MODE_TRADES)||OrderMagicNumber()!=MagicNumber||OrderType()!=OP_BUY) continue;
      //Check if the order is in profit of 100pips
            if(OrderOpenPrice()-sAsk>WhenToMoveToBE_*pips)
               if(OrderOpenPrice()<OrderStopLoss())
                  OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()-(PipsToLockIn*pips),OrderTakeProfit(),0,clrNONE);
   }
   return;
}

//+------------------------------------------+
//| 4. AdjustTrail                           |
//+------------------------------------------+
void AdjustTrail(string sym) //<<-- function for trailing stop base on number of pips moved
{
   double sAsk = MarketInfo(sym,MODE_ASK); double sBid = MarketInfo(sym,MODE_BID);

   //checking how many open orders on the current chart and loop through them until 0
   //BUY ORDERS
   int buyStopCandle=iLowest(sym,0,1,CandlesBack,1);
   int sellStopCandle=iHighest(sym,0,2,CandlesBack,1);
   int PadAmount_trail = PadAmount_Entry+10;
   double minBuySL = MathMax(sBid-(TrailAmount*pips),iLow(sym,0,buyStopCandle)-PadAmountTrailSL*pips);
   double maxSellSL = MathMin(sAsk+(TrailAmount*pips),iHigh(sym,0,sellStopCandle)+PadAmountTrailSL*pips);
   for(int b=OrdersTotal()-1; b >=0; b-- /*reduce by one*/) 
   {
   if(OrderSelect(b,SELECT_BY_POS,MODE_TRADES)) //select the order 
      if(OrderMagicNumber()==MagicNumber) //check if the selected order was opened by the EA base on the magic number
         //Note: the above line can be OrderMagicNumber()!=MagicNumber) continue; or break; to skip to next loop or break out loop
        if(OrderSymbol()==sym)
         if(OrderType()==OP_BUY) //check if it is a open buy order (exit loop for limit order)
      //Alternative filter: if(!OrderSelect(b,SELECT_BY_POS,MODE_TRADES)||OrderMagicNumber()!=MagicNumber||OrderType()!=OP_BUY) continue;
      //Check if the order is in profit of 100pips
        // if(OrderOpenPrice()<Ask-PadAmount_trail*pips) // check if the order is currently in profit or not (only trail if in profit)
            if(UseCandleTrail)
            {if(IsNewCandle(sym, Period()))
               if(OrderStopLoss()<iLow(sym,0,buyStopCandle)-PadAmountTrailSL*pips) //<--Check if the current SL is below the previou candle's Low minus the PadAmountTrailSL, if YES then move the SL up, Else no move
                  OrderModify(OrderTicket(),OrderOpenPrice(),iLow(sym,0,buyStopCandle)-(PadAmountTrailSL*pips),OrderTakeProfit(),0,clrNONE);
            }
            else if(sBid-OrderOpenPrice()>WhenToTrail*pips)
               if(OrderStopLoss()<minBuySL)
                 OrderModify(OrderTicket(),OrderOpenPrice(),minBuySL,OrderTakeProfit(),0,clrNONE);
   }
   //SELL ORDERS
   for(int s=OrdersTotal()-1; s >=0; s-- /*reduce by one*/) 
   {
   if(OrderSelect(s,SELECT_BY_POS,MODE_TRADES)) //select the order
      if(OrderMagicNumber()==MagicNumber) //check if the order is opened by the EA
         //Note: the above line can be OrderMagicNumber()!=MagicNumber) continue; or break; to skip to next loop or break out loop
        if(OrderSymbol()==sym)
         if(OrderType()==OP_SELL) //check if it is a open buy order (exit loop for limit order)
      //Alternative filter: if(!OrderSelect(b,SELECT_BY_POS,MODE_TRADES)||OrderMagicNumber()!=MagicNumber||OrderType()!=OP_BUY) continue;
      //Check if the order is in profit of 100pips
     // if(OrderOpenPrice()>Bid+PadAmount_trail*pips)
           if(UseCandleTrail)
            {if(IsNewCandle(sym, Period()))
               if(OrderStopLoss()>iHigh(sym,0,sellStopCandle)+PadAmountTrailSL*pips) //<--Check if the current SL is below the previou candle's Low minus the PadAmountTrailSL, if YES then move the SL up, Else no move
                  OrderModify(OrderTicket(),OrderOpenPrice(),iHigh(sym,0,sellStopCandle)+(PadAmountTrailSL*pips),OrderTakeProfit(),0,clrNONE);
              }    
            else if(OrderOpenPrice()-sAsk>WhenToTrail*pips)
                if(OrderStopLoss()>maxSellSL||OrderStopLoss()==0) //*OrderStopLoss==0 is the case where the trade does not have SL before this
                                                                              //this function is ran
                  OrderModify(OrderTicket(),OrderOpenPrice(),maxSellSL,OrderTakeProfit(),0,clrNONE);
   }
}

//+------------------------------------------------------------------------------+
//| 5. OpenOrdersThisPair                                                        |
//| Function to check through all symbol whether the OpenOrder is in that pair   |
//+------------------------------------------------------------------------------+
 int OpenOrdersThisPair(string pair, int order_type) //<-- set variable `pair' which receive the input Symbol() from function OrderEntry
   {
      int total=0; //<--initialize 
      for(int i=OrdersTotal()-1; i>=0; i--)
         {
            OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
            if(OrderSymbol()==pair && OrderType()==order_type) total++; //if there is one opened, the `total' var increase by that much
         }
        return(total); //put the number of total number open in this symbol
   
   }
   
  //+-function to determin ticksize
  double Getticksize(string symbol)
      {
      double ticksize = MarketInfo(symbol, MODE_TICKSIZE); //standardize ticksize (point) across different 5-digits and 4 digits brokers
      if (ticksize == 0.00001 || ticksize == 0.001) //point == 0.001 is meant for JPY crosses 
      pips = ticksize*10;
      else pips=ticksize;
      return(pips) ;
      }
  //--------------------

 //+------------------------------------------------------------------+
 //| OTHER SCRIPT                                                     |
 //+------------------------------------------------------------------+
 
    double ArrayAverage(double& array[])
   {
      double summation = 0; 
      for (int iArray = ArraySize(array) - 1; iArray >= 0; iArray--) summation += array[iArray];
      double average =    summation / ArraySize(array);
      if(average!=0)return(average);
      else 
         {
         Print("Error !!!", GetLastError());
         return(0);
         }
   }
  //---------------------------------------------------
  // Send push notification
  //--------------------------------------------------
  enum ENUM0_PUSHNOTIFICATION_TYPE{
	OrderExecNotif = 1,
	SignalNotif = 2
};

  string SendPushNotification ( //Order Execution && SignalTrigger
                               string SignalName,  //Name of signals 
                               ENUM0_PUSHNOTIFICATION_TYPE PushNotifTypes, //Type of Notification, 1 = Order Execute, 2 = Signal found
                               double Entry,
                               double SL,
                               double TP,
                               string pair,
                               string order_Type,
                               datetime order_openTime,
                               bool ShowAlertOnScreen=true,
                               bool UseMobileNotif=true,
                               bool UseEmailNotif=true)
  {
   //convert all vars to string
   string strEntry = IntegerToString(Entry);
   string strSL = IntegerToString(SL);
   string strTP = IntegerToString(TP);
   string strOrder_OpenTime = TimeToString(order_openTime);
   string NotifTypeTxt, intro;
   switch(PushNotifTypes)
   {
   case OrderExecNotif: 
      NotifTypeTxt = "OrderExec:: "; 
      intro = strOrder_OpenTime + "- New order opened:" + " " +
                  order_Type + " " ;
      break;
   case SignalNotif: 
      NotifTypeTxt = "SignalFound:: "; 
      intro = "parameters: " + order_Type + " " ;
      break;
   }
   //create the alert message
   string alert = SignalName +"|" + NotifTypeTxt+ intro +
                  pair  + 
                  "@ Entry: " + strEntry +
                  ", SL: " + strSL +
                  ", TP: " + strTP ;
   if(ShowAlertOnScreen==true)Alert(alert);
   if(UseMobileNotif==true){SendNotification(alert); Print(":::PUSH NOTIF SENT:::");}
   if(UseEmailNotif==true){SendMail("MAcross_EA alert: ", alert); Print(":::EMAIL NOTIF SENT:::"); }

   return(0);
  }
 

 //======RSIValidator==========================
 // Checking the RSI is being overbought or oversold
 enum ENUM_REVERSAL {NONE = 0, OVERBOUGHT=1, OVERSOLD=2};
  bool RSIReversalChk(string sym, int timeframe)
  {
    double RSI_value = iRSI(sym,timeframe,14,1,1); //check RSI value at H4 chart
    ENUM_REVERSAL reversal;
    if(RSI_value>rsiLo && RSI_value<rsiHi)reversal=0;
    if(RSI_value<=rsiLo || RSI_value>=rsiHi)reversal=1;
    return(reversal);
   }
   //+---------------------
   
 int SuppResisChk(string sym, double &inpArray[], ENUM_TIMEFRAMES TF1, ENUM_TIMEFRAMES TF2,
                     int lookback1, int lookback2
                     )
   {
   //ArrayResize(inpArray,4);

   if(iLowest(sym,TF1,MODE_LOW,lookback1,0)!=-1
      && iLowest(sym,TF2,MODE_LOW,lookback2,0)!=-1
      )
      {
   inpArray[0] =  Low[iLowest(sym,TF1,MODE_LOW,lookback1,0)]; 
   inpArray[1] =  Low[iLowest(sym,TF2,MODE_LOW,lookback2,0)];
   inpArray[2] =  High[iHighest(sym,TF1,MODE_HIGH,lookback1,0)]; 
   inpArray[3] =  High[iHighest(sym,TF2,MODE_HIGH,lookback2,0)];
   //Print("Supp1: ", Supp1, ", Supp2: ", Supp2, " ,Resis1:", Resis1, " ,Resis2 ", Resis2);
   return(0);
   }
   else
   {GetLastError(); return(-1);}
   }

string mkttype2txt(int trend)
  {
  string txt;
   switch(trend)
   {
   case 1: txt = "DOWNTREND OVERSOLD"; break;
   case 2: txt = "DOWNTREND NORMAL"; break;
   case 3: txt = "SIDEWAY"; break;
   case 4: txt = "SIDEWAY UP"; break;
   case 5: txt = "SIDEWAY DOWN"; break;
   case 6: txt = "UPTREND NORMAL"; break;
   case 7: txt = "UPTREND OVERBOUGHT"; break;
   }
      return(txt);
  }
  
string tradeexec2txt(int tradeexec)
  {
  string txt;
   switch(tradeexec)
   {
   case 0: txt = "NOTRADE"; break;
   case 1: txt = "BUYONLY"; break;
   case 2: txt = "SELLONLY"; break;
   case 3: txt = "NEUTRAL"; break;
  
   }
      return(txt);
  }
  
  

  //---------------------------------------------------
  // NewsFilter
  //--------------------------------------------------
bool AvoidNewsChk( bool avoidNewsx,
                  int MinImpactx,
                  int MinsBeforeNewsx,
                  int MinAfterNewsx)
{
   bool AvoidTrading=false;
   string newsAlert;
   if(avoidNewsx)
   {
      static int PrevMinute=-1;  
            
      datetime NewsWindowTimeStart=0; 
      datetime NewsWindowTimeEnd=0; //the time period threshold, define by MinsBeforNews and MinsAfterNews

      
      //get the minutes to news and News impact
      int MinToNews=iCustom(NULL,0,FFCalPath,0,0); 
      int ImpactToNews=iCustom(NULL,0,FFCalPath,1,0);
      
      //read the time if MinToNews is only 30 minutes away from the News release
      if(MinToNews==MinsBeforeNews)
         {
            NewsWindowTimeStart = TimeCurrent(); //record the current time
            NewsWindowTimeEnd = TimeCurrent()+(MinsBeforeNewsx+MinAfterNewsx)*60; //Get the future time where news window end
         }


      if(Minute()!=PrevMinute)
      {
          PrevMinute=Minute();
          if((MinToNews<=MinsBeforeNewsx &&  ImpactToNews>=MinImpactx) || 
            (TimeCurrent()<=NewsWindowTimeEnd))
          AvoidTrading=true;
          newsAlert = "MinToNews: " + MinToNews + ", ImpactToNews: " + ImpactToNews + " ,HIGH IMPACT NEWS, ONLY TRADE AFTER " + NewsWindowTimeEnd ;        
          Alert(newsAlert);
      }
      else {
         newsAlert =  "MinToNews: " + MinToNews + ", ImpactToNews: " + ImpactToNews + ", " + NewsWindowTimeEnd;
         Print(newsAlert);
         }

         return(AvoidTrading);

   }
   else return(false);
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Arrow Draw function                                              |
//+------------------------------------------------------------------+

color ArrowUpclr = clrBlue;
color ArrowDwclr = clrRed;
enum ENUM0_DIRECTION {_UP=0, _DOWN=1 };
double rates_d1[][6];
//+----------------------------------
bool ShowBuyArrowOnChart(long chart_ID, string name="ArrowUpName",  datetime time=0, double price=0.0, ENUM0_DIRECTION dir=_UP)
{
if (ObjectFind(name) != 0) ArrowCreate(chart_ID, name, 0, time, price, dir);
     else ArrowMove(chart_ID,name,time, price);
   return(true);
}

bool ShowSellArrowOnChart(long chart_ID, string name="ArrowDwName",  datetime time=0, double price=0.0, ENUM0_DIRECTION dir=_DOWN)
{
if (ObjectFind(name) != 0) ArrowCreate(chart_ID, name, 0, time, price, dir);
     else ArrowMove(chart_ID,name,time, price);
   return(true);
}


//+------------------------------------------------------------------+
//| ArrowCreate function                                             |
//+------------------------------------------------------------------+

bool ArrowCreate(long              chart_ID=0,           // chart's ID 
                   string            name="ArrowUp",       // sign name 
                   int               sub_window=0,         // subwindow index 
                   datetime                time=0,               // anchor point time 
                   double                  price=0,              // anchor point price
                   ENUM0_DIRECTION dir= _UP, 
                   ENUM_ARROW_ANCHOR anchor=ANCHOR_BOTTOM,  //// anchor type
                   ENUM_LINE_STYLE   style=STYLE_SOLID,    // border line style 
                   int               width=4,              // sign size 
                   bool              back=false,           // in the background 
                   bool              selectable=true,       // highlight to move
                   bool              selected=false,       // highlight to move 
                   bool              hidden=true,          // hidden in the object list 
                   long              z_order=0            // priority for mouse click
                  ) 
     {
   int arrcode;    // border line style
   color clr;           // sign color 
     //--- set anchor point coordinates if they are not set 
  // ChangeArrowEmptyPoint(time,price); 
//--- reset the error value 
   ResetLastError(); 
//--- create the sign 
   if(!ObjectCreate(chart_ID,name,OBJ_ARROW_BUY,sub_window,time,price)) 
     { 
      Print(__FUNCTION__, 
            ": failed to create \"Arrow Up\" sign! Error code = ",GetLastError()); 
      return(false); 
     }

   if(dir==_UP)
      {
         arrcode=233;
         clr = ArrowUpclr;
      }
   if(dir==_DOWN)
   {
      arrcode=234;
      clr = ArrowDwclr;
      }
//--- set anchor type 
   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,anchor); 
//--- set a sign color 
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr); 
//--- set the border line style 
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set the Arrow code 
   ObjectSetInteger(chart_ID,name,OBJPROP_ARROWCODE,arrcode);  
//--- set the sign size 
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width); 
//--- display in the foreground (false) or background (true) 
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back); 
//--- enable (true) or disable (false) the mode of moving the sign by mouse 
//--- when creating a graphical object using ObjectCreate function, the object cannot be 
//--- highlighted and moved by default. Inside this method, selection parameter 
//--- is true by default making it possible to highlight and move the object 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selectable); 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selected); 
//--- hide (true) or display (false) graphical object name in the object list 
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden); 
//--- set the priority for receiving the event of a mouse click in the chart 
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order); 
//--- successful execution 
   return(true); 
  } 

//+------------------------------------------------------------------+ 
//| Moving arrow Arrow Up sign                                       | 
//+------------------------------------------------------------------+ 
bool ArrowMove(long   chart_ID=0,     // chart's ID 
                 string name="ArrowUp"  , // object name 
                 datetime     time=0,         // anchor point time coordinate 
                 double       price=0)        // anchor point price coordinate 
  
  {
//--- if point position is not set, move it to the current bar having Bid price 
   if(!time) 
      time=TimeCurrent(); 
   if(!price) 
      price=SymbolInfoDouble(Symbol(),SYMBOL_BID); 
//--- reset the error value 
   ResetLastError(); 
//--- move the anchor point 
   if(!ObjectMove(chart_ID,name,0,time,price)) 
     { 
      Print(__FUNCTION__, 
            ": failed to move the anchor point! Error code = ",GetLastError()); 
      return(false); 
     } 
//--- successful execution 
   return(true); 
  } 

//+------------------------------------------------------------------+ 
//| Delete Arrow Up sign                                             | 
//+------------------------------------------------------------------+ 
bool ArrowUpDelete(const long   chart_ID=0,     // chart's ID 
                   const string name="ArrowUp") // sign name 
  { 
//--- reset the error value 
   ResetLastError(); 
//--- delete the sign 
   if(!ObjectDelete(chart_ID,name)) 
     { 
      Print(__FUNCTION__, 
            ": failed to delete \"Arrow Up\" sign! Error code = ",GetLastError()); 
      return(false); 
     } 
//--- successful execution 
   return(true); 
  } 

bool IsNewCandle(string sym, int period)
 {
   static int BarsOnChart=0; //static ==> only initialized once, if global then ==> int BarsOnChart=0;
   if(iBars(sym,period)==BarsOnChart)
   return(false);
   BarsOnChart = iBars(sym,period); 
   return(true);
 }

/*  
double CheckLastOrder(int period, string symbol)
{
   //(ATR of last bar – min ATR in last n-bars) / (max ATR in last n-bars – min ATR in last n-bars)
   
   int z,c_average;
   double arr[10];
   double nATR;
   if (period<1) period=3;     // Min period is 3
   if (period>10) period=10; // Max period is 100

   // Get the 
   for(z=0;z<period;z++) arr[z]=iATR(symbol,TFSlope,period,z+1);
   c_min=ArrayMinimum(arr,period,0);
   c_max=ArrayMaximum(arr,period,0);
   
   if ((arr[c_max] - arr[c_min])!=0)
   {
    nATR=( ( iATR(symbol,TFSlope,period,1) -  arr[c_min] ) / ( arr[c_max] - arr[c_min] ) ); 
      if (nATR<0) nATR=0;     // Min period is 3
      if (nATR>1) nATR=1; // Max nATR is 100
   }
   else 
      nATR = 0;
   return(nATR);

}
*/

extern bool MobileNotification=true;
extern bool EmailNotification=true; 
int CloseHighRiskPairs(string CurrencyList, string ClosingTimeOnChart) //<<-- function for trailing stop base on number of pips moved
{
   string CurrArr[]; 
   string currency, msg;
   string sep=",";
   ushort u_sep=StringGetCharacter(sep,0);
   int k=StringSplit(CurrencyList,u_sep,CurrArr);
   if(k>0)
     {
      for(int i=0;i<k;i++)
        {
         //PrintFormat("result[%d]=%s",i,SymArr[i]);
         currency=CurrArr[i];
            //checking how many open orders on the current chart and loop through them until 0
            for(int b=OrdersTotal()-1; b >=0; b-- )// loop thru opening order
            {
               if(OrderSelect(b,SELECT_BY_POS,MODE_TRADES)) //select the order 
               {
                  if(StringFind(OrderSymbol(),currency, 0)>-1 && //found the correct pair
                  (OrderType()==OP_BUYLIMIT || OrderType()==OP_SELLLIMIT) &&              //Only close limit orders;
                  TimeToStr(Time[0],TIME_MINUTES)==ClosingTimeOnChart //check Charttime
                    )
                       {
                          if(OrderDelete(OrderTicket(),Magenta))
                           {
                            msg = "[CloseHighRiskPairs] Limit order Pos #" + b + "ticket: " + OrderTicket()+ "\n" + 
                            " is closed b/c " + currency + " is higly risky now" ;
                              if(MobileNotification)SendNotification(msg); 
                           Print(msg);
                           }
                          else Print("OrderDelete fail!!!",GetLastError());   
                         }
                       }
                 }
         }
   }
   return(0);
}


datetime StrLocalTimeToServerTime(string localTime)
{
   datetime LocalTimeDT = StrToTime(localTime);
   double TimeDiff = MathRound(TimeCurrent() -  TimeLocal());
   datetime ChartTime = LocalTimeDT + TimeDiff;
   return(ChartTime);
}

int dummyOrderSend(string sym, ENUM_ORDER_TYPE ordertyp, double Lots)
   {
   double vbid    = MarketInfo(sym,MODE_BID); 
   double vask    = MarketInfo(sym,MODE_ASK); 
   double vpoint  = MarketInfo(sym,MODE_POINT); 
   int    vdigits = (int)MarketInfo(sym,MODE_DIGITS); 
   int    vspread = (int)MarketInfo(sym,MODE_SPREAD);
   double entry;
   switch(ordertyp)
   {
   case OP_BUY: entry=vask; break;
   case OP_BUYLIMIT: entry=vask - 500*MarketInfo(sym,MODE_POINT); break;
   case OP_SELL: entry=vbid;
   case OP_SELLLIMIT: entry=vbid + 500*MarketInfo(sym,MODE_POINT);
   }
   if(OrderSend(sym,ordertyp,Lots,entry,3,0,0,"TestingOrder",clrRed)) return(0); else return(-1);
  }
  
     string tf2txt(int tf)
   {
      if(tf==PERIOD_M1) return("M1");
      if(tf==PERIOD_M5) return("M5");
      if(tf==PERIOD_M15) return("M15");
      if(tf==PERIOD_M30) return("M30");
      if(tf==PERIOD_H1) return("H1");
      if(tf==PERIOD_H4) return("H4");
      if(tf==PERIOD_D1) return("D1");
      if(tf==PERIOD_W1) return("W1");
      if(tf==PERIOD_MN1) return("MN1");
      //----
      return("??");
   }