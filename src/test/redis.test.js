import { Redis } from 'ioredis'

const client = new Redis()


const func = async () => {
    // await client.set("name","Suhail")
    // await client.set("user:1","Suhail")
    // await client.setnx("name","Suhail")//set only if such key doesnt exists
    //await client.get("name")
    // await client.del("message")
    // console.log(await client.keys("user*"))//pattern based


    //list opr
    // await client.lpush("message","Hi")
    // console.log(await client.lpop("message"));
    // console.log(await client.blpop("message",10));//pop by waiting for 10 sec
    // console.log(await client.lrange("message",0,await client.llen("message")));//from first to end, other o,

    //set opr,ex:track 
    // console.log(await client.sadd("ip",1));//sadd(setName,key)
    // console.log(await client.sismember("ip",1));//sismember(setName,val)



    //hash set
    // console.log(await client.hset('key1',{'name':'Suhail','dob':"balh"}));

    //sorted set
    console.log(await client.zadd("score",1,"john"));
    
    
    
    
    
}

func()

/**
Example chat app in redis:

Receiver side:
docker exec -it <id> sh
redis-cli
subscribe msg
//now this will listen messages publshed

Sender side:
docker..
redis-cli
publish msg "hi how are u?"
 * 
 */

/**
 * 
How to cache in redis?
//example 
async(){
    if(await redis.get('name')) return JSON.parse(redis.get('name'))
    const data=await axios.get('some complex api)
    redis.set('name',JSON.stringgify(data))
    redis.expire('name',30) //expire after 30 seconds
}
 */