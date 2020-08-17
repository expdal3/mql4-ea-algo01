//+------------------------------------------------------------------+
//|                                                      Algo_01.mq4 |
//|                                         Copyright 2019, Andre Le |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Andre Le"
#property link      "https://www.mql5.com"
#property version   "1.01"
#property strict

input string Main1 = "---General settings---";
extern ENUM_TIMEFRAMES MACrossSignalTimeFrame=PERIOD_H1;
extern string MACrossIndiPath = "CustomIndi\\Trend and stochastics\\MACrossIndi";

extern bool IsTradingAllowed = false; //IsTradingAllowed
extern int  FixProfitPips=500;
extern int  FixStopPips=600;
extern int EATimeframe=PERIOD_H1; //Seting the Timeframe which the the EA MA will be drawn on

//===Use Percent SL / TP In OrderEntry function==============
input string Main2 = "---Risk Management Placing Order---";
extern bool UsePercentStop=True;
extern bool UsePercentTakeProfit=True;
extern int RiskPcnt=2;
extern double Reward_ratio=2;

//--setting vars for not opening trade after a previous order has opened recently------
input string Main3 = "Positions management 1: No new order after a newly opened positions---";
extern bool UseLimitOrder = true;
extern int LastOrderLimit = 18; //number of candles from the last opened order

double EALotSizeFactor;
double OrderLotSize = 0;
int LastOrderCandle = 0; //Most recent candle with order opened
int LastOrderGap; //buyLastOrderGap
//import all dependencies
#include "Dependencies\\TradeUtility.mqh"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   //Adjust for 5 digits brokers pips:
   if(Digits==3 || Digits ==5)
         pips*=10;
   
      //specify lot size
   switch(LotSizeFactor)
        {
         case Standard: EALotSizeFactor = 1; break;
         case Mini:    EALotSizeFactor = 0.1 ; break;
         case Micro:   EALotSizeFactor = 0.01 ; break;
        }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- calling trading strategy
   ExecuteTradingStrategy(Symbol(),Period());
   //----
  }
//+------------------------------------------------------------------+

void ExecuteTradingStrategy(string sym, int period)
{
   //managing opening orders
   if(UseMoveToBreakeven)MoveToBreakeven(sym);
   if(UseTrailingStop)AdjustTrail(sym);
   PartialClose(sym);
   
   //--check for signal on new candle and execute new order-------------
   if(IsNewCandle(sym, period))
     { 
      CheckForMACrossTrade(sym, MACrossSignalTimeFrame);
     }
}

//declare output array for CheckForMACrossTrade
struct MACrossSignalDict {int CrossSignal; int CrossTime; }; //initialize MAcross signal output data dictionary
MACrossSignalDict MACrossSignalData={0,0}; 
extern int FastMA=5; extern int FastMAShift=0; extern int FastMAMethod=1; extern int FastMAAppliedTo=0;
extern int SlowMA=21; extern int SlowMAShift=0; extern int SlowMAMethod=1; extern int SlowMAAppliedTo=0;
extern int BarsToCheckRecentMACross = 10; //number of bars to lookback for recent MA cross

int CheckForMACrossTrade(string sym, int period) //this function is trading the Ma EA
{
   //Access MACrossSignal's data:
   CheckMACrossSignal(sym,period, 0, BarsToCheckRecentMACross); //<-- pass in data
   //Call order execution if all signals is valid
    if(RSIReversalChk(sym, RSIReversalChkTimeFrame)!=OVERSOLD   //market is not oversold
         && MACrossSignalData.CrossSignal == 1)                //clean cross up signal confirmed
        {
         OrderEntry(sym, 0 , 0, IsTradingAllowed);                //Execute BUY order
         return(1);
        }
    else if(RSIReversalChk(sym, RSIReversalChkTimeFrame)!=OVERBOUGHT   //market is not overbought
      && MACrossSignalData.CrossSignal == -1)                     //clean cross down signal confirmed
        {
         OrderEntry(sym, 1, 0, IsTradingAllowed);               //Execute SELL order
         return(2);
        }
    else return(0);
}




//+------------------------------------------------------------------+
//| OrderEntry                                                                 |
//+------------------------------------------------------------------+
void OrderEntry(string sym, ENUM_TIMEFRAMES tf, int direction, bool TradingAllow)
  {
   double sAsk = MarketInfo(sym,MODE_ASK); double sBid = MarketInfo(sym,MODE_BID);
   double prevClose = iClose(sym, tf, 1); double prevOpen = iOpen(sym, tf, 1);
   double prevPriceForLimBuyEntry = MathMin(prevClose, prevOpen); //prev. price of limit Buy entry price
   double prevPriceForLimSellEntry = MathMax(prevClose, prevOpen); //prev. price of limit Sell entry price

   //convert risk and reward percentage to no. of pips
   double Equity = AccountEquity(); //get the account equity
   double RiskedAmt = Equity*RiskPcnt*0.01; //computing the risking amount in dollar term
   
   // Determine the StopLoss of Buy/Sell order base on the Highest/Lowest Candle:
   int buyStopCandle = iLowest(sym,0,1,CandlesBack,1);
   int sellStopCandle = iHighest(sym,0,2,CandlesBack,1);
   double buyStopPrice = iLow(sym,0,buyStopCandle)-PadAmountTrailSL*pips;
   double sellStopPrice = iHigh(sym,0,sellStopCandle)+PadAmountTrailSL*pips;

   //Determin the TakeProfit of the order base on R:R ratio
   double buyProfitPrice = sAsk+((sAsk-buyStopPrice)*Reward_ratio);
   double sellProfitPrice = sBid-((sellStopPrice-sBid)*Reward_ratio);
   double EntryPrice, bsl, btp, ssl, stp;
   string Order_Type;


   int buyTicket, sellTicket;
   //================BUY order==============
   if(direction==0)
     {
      //Calculat the lotsize: Risked Amount / no. of pips to get $$ amt risked per pips
      if(UseLimitOrder==false)EntryPrice=sAsk;
      else EntryPrice=prevPriceForLimBuyEntry; //use prev open price in case of LimitOrder
      bsl = buyStopPrice;
      btp = buyProfitPrice;

      OrderLotSize=NormalizeDouble(RiskedAmt/((EntryPrice-bsl)/pips),2) * EALotSizeFactor ; //10 is the miniLot (0.1 Lot), 100 is the microLot (0.01 Lot)
      //Print("LotSize ", LotSize);

      // Main BUY trade execution part-----------------------
      if(OpenOrdersThisPair(sym,0)<=NoBUYActiveTrade)            //--Check number of current BUY active orders
            if(TradingAllow) //If trading is allowed
              {
              //MARKET BUY ORDER
               if(UseLimitOrder==false && 
                   IsThereRecentPosition(sym,OP_BUY,HourFromLastPosition)==false //check if there is not a recent BUY order opened;
                  ) 
                 {
                  buyTicket=OrderSend(sym,OP_BUY,OrderLotSize,EntryPrice,3,bsl,btp,"MAx EA v2-BUY MarketOrder",MagicNumber,
                                      0,clrGreen);
                  Order_Type = "OP_BUY";
                 }
               else //FOR LIMIT BUY ORDER
                 {
                  if(OpenOrdersThisPair(sym,OP_BUYLIMIT)<=NoBUYPendingTrade
                     && IsThereRecentPosition(sym,OP_BUYLIMIT,HourFromLastPosition)==false
                     )
                     buyTicket=OrderSend(sym,OP_BUYLIMIT,OrderLotSize,EntryPrice,3,bsl,btp,"MAx EA v2-BUY LimOrder",MagicNumber,
                                         0,clrGreen);
                  Order_Type = "OP_BUYLIMIT";
                 }
               if(buyTicket>0) LastOrderCandle = iBars(sym,0);
               //Send BUY ORDER notification
               SendPushNotification("[MACross]",OrderExecNotif, EntryPrice, bsl, btp, sym, Order_Type,Time[0],1,MobileNotification, EmailNotification);
               Print("[OrderEntry] ", Order_Type, " ", ", buyTicket:", buyTicket," , LotSize: ",OrderLotSize, " EntryPrice: ",EntryPrice," SL: ", bsl, " TP: ",btp);
               //Print("LastOrderCandle is ", LastOrderCandle, "LastOrderGap is ", LastOrderGap);
              }
               else //if trading is NOT allowed (Signal Only)
              {
               SendPushNotification("[MACross]", SignalNotif, EntryPrice, bsl, btp, sym, Order_Type,Time[0],1,MobileNotification, EmailNotification);
              }
              
      //+-------------------------------------------------
     }
//Note: For EA, cannot use "NULL" like in indicator function

//--------sell order----------------
   if(direction==1) 
     {
         if(UseLimitOrder==false) EntryPrice=sBid;
         else EntryPrice=prevPriceForLimSellEntry;
         bsl = sellStopPrice;
         btp = sellProfitPrice;

      OrderLotSize=NormalizeDouble(RiskedAmt/((ssl-EntryPrice)/pips),2) * EALotSizeFactor; // 

      //check how many current opened Sell orders
      if(OpenOrdersThisPair(sym,1)<=NoSELLActiveTrade)
            if(TradingAllow) //If trading is allowed
              {
               if(UseLimitOrder==false
                  &&  IsThereRecentPosition(sym,OP_SELL,HourFromLastPosition)==false //check if there is not a recent Sell order opened;

                  ) //if not using limit order
                 {
                  sellTicket= OrderSend(sym,OP_SELL,OrderLotSize,EntryPrice,3,ssl,stp,"MAx EA v2-SELL MarketOrder",MagicNumber,
                                        0,clrRed);
                  Order_Type = "OP_SELL";
                 }
               else
                 {
                  if(OpenOrdersThisPair(sym,OP_SELLLIMIT)<=NoSELLPendingTrade
                     && IsThereRecentPosition(sym,OP_SELLLIMIT,HourFromLastPosition)==false
                     )
                     sellTicket= OrderSend(sym,OP_SELLLIMIT,OrderLotSize,EntryPrice,3,ssl,stp,"MAx EA v2-SELL LimOrder",MagicNumber,
                                           0,clrRed);
                  Order_Type = "OP_SELLLIMIT";
                 }
               if(sellTicket>0)
                  LastOrderCandle = iBars(sym,0);

               //Send notification
               SendPushNotification("[MACross]", OrderExecNotif, EntryPrice, ssl, stp, sym, Order_Type,Time[0],1,MobileNotification, EmailNotification);
               Print("[OrderEntry] ", Order_Type, " ",", sellTicket:", sellTicket," , LotSize: ",OrderLotSize, " EntryPrice: ",EntryPrice," SL: ", bsl, " TP: ",btp);
              }
                  else //if trading is NOT allowed (Signal Only)
              {
               SendPushNotification("[MACross]",SignalNotif, EntryPrice, ssl, stp, sym, Order_Type,Time[0],1,MobileNotification, EmailNotification);
              }
     }
  } //end OrderEntry

int CheckMACrossSignal(string sym, int period, int shift, int barsToCheck)
{
   //Getting the signal from MACrossIndicator
   double CrossSignalArray[];
   ArrayInitialize(CrossSignalArray,0);
   ArraySetAsSeries(CrossSignalArray,true);
   for(int i=ArrayResize(CrossSignalArray,barsToCheck)-1; i>=0; i--)
   {
      CrossSignalArray[i]= iCustom(sym,period,MACrossIndiPath,3,
            FastMA, FastMAShift, FastMAMethod, FastMAAppliedTo, //FastMA params
            SlowMA, SlowMAShift, SlowMAMethod, SlowMAAppliedTo, //SlowMA params   
            i);
      }
   double CrossSignalAverage= iMAOnArray(CrossSignalArray,0,BarsToCheckRecentMACross,0,MODE_SMA,0);

   //Only pass in signal if there is no recent cross with X amount of bars  
   if(CrossSignalAverage==0) 
     {
      //1. CrossSignal
      MACrossSignalData.CrossSignal = iCustom(sym,period,MACrossIndiPath,3,
         FastMA, FastMAShift, FastMAMethod, FastMAAppliedTo, //FastMA params
         SlowMA, SlowMAShift, SlowMAMethod, SlowMAAppliedTo, //SlowMA params   
         shift);
      // 2. CrossTime
      MACrossSignalData.CrossTime = iCustom(sym,period,MACrossIndiPath,4,
         FastMA, FastMAShift, FastMAMethod, FastMAAppliedTo, //FastMA params
         SlowMA, SlowMAShift, SlowMAMethod, SlowMAAppliedTo, //SlowMA params 
         shift);
     }
   //---------------
   return(0);
}

extern int HourFromLastPosition = 2;
bool IsThereRecentPosition(string sym, int ordertype, int hour)
{
   //checking how many open orders on the current chart and loop through them until 0
   int NoNewTradeDuration = hour * 60 * 60; //= 2 Hours or 120 mins

     for(int b=OrdersTotal()-1; b >=0; b-- )// loop thru opening order
   {
      if(OrderSelect(b,SELECT_BY_POS,MODE_TRADES)) //select the order 
      {
         if(OrderMagicNumber()==MagicNumber && OrderSymbol()==sym
         && OrderType()==ordertype
         ) //Only close limit orders;
               {
              int duration = TimeCurrent() - OrderOpenTime(); //check duration of Current time versus the Current selected order's opening time
               if (duration <= NoNewTradeDuration)
                  {
                   Print("[IsThereRecentPosition] = true, some position has been opened for ", sym ," in the last ", hour, " hours");
                     return(true);
                  }
              }
        }
      //else return(false);   
   }
  return(false);
}