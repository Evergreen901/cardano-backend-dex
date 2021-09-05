{ getHttpSettings = 
    { getHost = "127.0.0.1"
    , getPort = 8012
    },
getKafkaProducerSettings = 
    { getBrokersList = ["127.0.0.1:9092"]
    , getAmmTopic = "amm-topic"
    , getProxyTopic = "proxy-topic"
    , getProxyMsgKey = "default-proxy-key"
    , getAmmMsgKey = "default-amm-key" 
    },
  getBlockRequestSettings =
    { getPeriod = 0
    }
}