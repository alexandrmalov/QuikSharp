﻿using System.Collections.Generic;
using System.Threading.Tasks;
using QuikSharp.DataStructures;

namespace QuikSharp
{
    /// <summary>
    /// Функции для получения свечей
    /// </summary>
    public class CandleFunctions
    {

        public QuikService QuikService { get; private set; }

        public delegate void CandleHandler(Candle candle);
        /// <summary>
        /// Событие получения новой свечи. Для срабатывания необходимо подписаться с помощью метода Subscribe.
        /// </summary>
        public event CandleHandler NewCandle;
        internal void RaiseNewCandleEvent(Candle candle)
        {
            if (NewCandle != null)
                NewCandle(candle);
        }

        public CandleFunctions(int port) { QuikService = QuikService.Create(port); }


        /// <summary>
        /// Функция предназначена для получения информации о свечках по идентификатору (заказ данных для построения графика плагин не осуществляет, поэтому для успешного доступа нужный график должен быть открыт). Возвращаются все доступные свечки.
        /// </summary>
        /// <param name="graphicTag">Строковый идентификатор графика или индикатора</param>
        /// <returns></returns>
        public async Task<List<Candle>> GetAllCandles(string graphicTag)
        {
            return GetCandles(graphicTag, 0, 0, 0).Result;
        }

        /// <summary>
        /// Функция предназначена для получения информации о свечках по идентификатору (заказ данных для построения графика плагин не осуществляет, поэтому для успешного доступа нужный график должен быть открыт).   
        /// </summary>
        /// <param name="graphicTag">Строковый идентификатор графика или индикатора</param>
        /// <param name="line">Номер линии графика или индикатора. Первая линия имеет номер 0</param>
        /// <param name="first">Индекс первой свечки. Первая (самая левая) свечка имеет индекс 0</param>
        /// <param name="count">Количество запрашиваемых свечек</param>
        /// <returns></returns>
        public async Task<List<Candle>> GetCandles(string graphicTag, int line, int first, int count)
        {
            var message = new Message<string>(graphicTag + "|" + line + "|" + first + "|" + count, "get_candles");
            Message<List<Candle>> response = await QuikService.Send<Message<List<Candle>>>(message);
            return response.Data;
        }

        public async void Subscribe(string classCode, string securityCode, CandleInterval interval)
        {
            var message = new Message<string>(classCode + "|" + securityCode + "|" + (int)interval, "subscribe_to_candles");            
            await QuikService.Send<Message<string>>(message);
        }

        public async void Unsubscribe(string classCode, string securityCode, CandleInterval interval)
        {
            var message = new Message<string>(classCode + "|" + securityCode + "|" + (int)interval, "unsubscribe_from_candles");            
            await QuikService.Send<Message<string>>(message);     
        }

        public async Task<bool> IsSubscribed(string classCode, string securityCode, CandleInterval interval)
        {
            var message = new Message<string>(classCode + "|" + securityCode + "|" + (int)interval, "is_subscribed");
            Message<bool> response = await QuikService.Send<Message<bool>>(message);
            return response.Data;
        }
    }
}
