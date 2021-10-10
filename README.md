# aws-lambda-aperotech

## Step 1 - First Lambda

1) Create the lambda  

Connect to your AWS account.  
Search for Lambda service either using drop down menu `services` or using the searchbar.  

Click `Create function`  
Enter a function name of your choice and select `Node.js 14.x` runtime.

Leave the other configuration options as is and click `Create function` again.  
After a while, you are redirected to your newly created function.
Take a few minutes to navigate the UI.

2) Execute your lambda

Play around with the Code editor under code tab.  
Execute the lambda by clicking `Test`. (if you made a modification, don't forget to hit `deploy` button)

Change the return value and configure a test event to find out what inputs and outputs look like.  
💡 Tip: You can log just by using console.log  
⚠️ Your function return value "must" be encapsulated in a promise 


## Step 2 - Going public

Now we want to make this lambda available to the world.  
To make that happen, we are going to create a public endpoint which will route requests to our lambda.  

In the function overview block, at the top of the lambda page, click `Add trigger` and select API Gateway.  
Choose the HTTP API type and an open security and click `Add`.  

Now that you have a endpoint configured, let's check it out.  
Click the newly created `API Gateway` block in the Function overview and reveal the URL to invoke your lambda.  
It should look something like this:  
`https://73cfjh04u2.execute-api.eu-west-1.amazonaws.com/default/your-lambda-name`  
Accessing this URL with your browser will trigger a function invocation and display the result. 
You can log the event to check what an API Gateway -> Lambda invocation look like and play around with query params to change your lambda's behaviour.

You can also invoke the lambda by sending a POST request on the same URL and have an easier time handling parameters.

## Step 3 - Using it in a webapp

Under the app folder, you will find a pretty classic and simple html app.

1) Bootstrap the app

Install the dependencies  
`yarn`  
Run the app using webpack dev server  
`yarn start`

2) Call the lambda

- Using http call  
In the `app.js` file, call your lambda using axios and display the result.   


- Using [aws-sdk](https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/Lambda.html#invoke-property)  
Another possibility is to use the AWS SDK in Javascipt that offers a lot of possibilities accross services. Use it to invoke the lambda from your `app.js` 

Using the SDK doesn't require an endpoint, but you will need to create a user from your [aws users page](https://console.aws.amazon.com/iamv2/home?#/users) and use its `accessKeyId` and `secretAccessKey` to get authenticated.
Store the secret somewhere because you can only see it at user's creation.  
Also note its identifier (arn) for the next step.    
Then, to be allowed to invoke the lambda with this user, you will create a policy from the configuration tab on the lambda page.  
(Permissions -> add Permissions -> Aws Account -> fill in the blanks)

You can now write your application code to invoke the lambda.  
💡 You will need to authenticate with the credentials of the user you created.
<details>  
<summary>
Spoiler - Lambda JS invocation
</summary>  

```js
import AWS from 'aws-sdk';
const lambda = new AWS.Lambda({
    credentials: new AWS.Credentials({
        accessKeyId: 'foo',
        secretAccessKey: 'bar',
    }),
    region: 'eu-west-1', // Or whatever region you created your lambda in
});
lambda.invoke({
    FunctionName: 'your-lambda-name', 
    Payload: JSON.stringify(payload),
})
.promise();
```

</details>

## Step 4 - Bring superpowers to the front end 🚀️

Depending on the time you have left, you can either do part A or B (or both 🎉)

### A - Store data serverless using dynamoDB 💾

You'll first need to create a table to store data. Reach out to dynamoDB service page to start.  
DynamoDB are NoSQL storage table. For the purpose of this example, create the table with a partition key named `task` and a sort key named `label`.

Then go to the IAM service to give your lambda the rights to store and read data in this DB.  
To ensure that, start with creating a policy which gives rights to `getItem`, `putItem`, `scan` and `query` on the table you just created.  
Once this policy is created, you must attach it to the role which is used to run your lambda. (you can find the role arn on the lambda configuration tab)

And finally, in the lambda, use the sdk to put an Item in your db when it's invoked with parameters and read and return items in DB when it's invoked without parameters. You can also create a different function...  
Here are the SDK documentations of the functions which might be useful 😉  
[getItem](https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/DynamoDB.html#getItem-property)  
[putItem](https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/DynamoDB.html#putItem-property)  
[scan](https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/DynamoDB.html#scan-property)  

💡 _Hint:_ You are automatically authenticated with the role of your lambda inside the lambda and can access the `aws-sdk` as if you provided the source for it (`const AWS = require('aws-sdk')`)

<details>  
<summary>
Spoiler - Lambda code to store and read items
</summary>  

```js
const { DynamoDB } = require('aws-sdk');

const dynamoDB = new DynamoDB();

// Store an item
await dynamoDB.putItem({
    Item: DynamoDB.Converter.marshall({task: 'myTask', label: 'home', description: 'ranger la cave'}),
    TableName: 'aperotech1',
}).promise();

// Read items in a table
await dynamoDB.scan({ TableName: 'aperotech1' }).promise();
```
</details>  

You can then either run the lambda through the AWS console interface or use the app created in step 3 and build some UI to store, display and delete your tasks.  

### B - Invoke binary inside the lambda (layers) 🤓

This is becoming a bit more tricky 🥷

Here we will create a gif based on a video. To do that, we will use [gifgen](https://github.com/lukechilds/gifgen) and [ffmpeg](https://www.ffmpeg.org/).  

So let's create two separate [layers](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html) one for each binaries above to promote reusing them.  
Layers offer the possibility to enhance your lambda runtime by making binaries available to your code and limit the overhead at lambda's start. 

Once these layers are ready, create a new lambda which will read [this video](https://www.youtube.com/watch?v=cyQtMZBZJlk&ab_channel=ExquisClafoutis) from a public s3 (s3://aperotech/BEST OF OSS 117-cyQtMZBZJlk.mkv), then use gifgen to create your gif and finally return it as a Base64 string.   
The Base64 makes it possible for the front end app to embed it right away as an image.  

(⚠ beware that you should limit gif length to 2 seconds of video. Indeed, for simplicity purposes we stay under lambda return size limit thus avoiding setting up an s3 on your account)  

💡 Hint: This lambda needs more power and will take longer time to execute... Tweak the configuration to fit your needs 🛠
<details>  
<summary>
Spoiler - Lambda code to fetch video on S3 and convert it to a gif
</summary>  

```js
const { S3 } = require('aws-sdk');
const {  execSync } = require('child_process');
const { readFileSync, writeFileSync } = require('fs');

const localVideoName = "/tmp/video.mkv";
const localGifName = "/tmp/video.gif";

const s3 = new S3();
const getObjectFromS3 = (params) => s3
    .getObject(params)
    .promise()
    .then(({ Body }) => {
        return Body;
    });

exports.handler = async event => {
    const {
        Bucket = 'aperotech',
        Key = 'BEST OF OSS 117-cyQtMZBZJlk.mkv',
        start = 0 } = event.queryStringParameters || event;

    const video = await getObjectFromS3({ Bucket, Key });

    writeFileSync(localVideoName, video);

    execSync(`gifgen -b ${start} -d 2 -o ${localGifName} ${localVideoName}`);

    const gif = readFileSync(localGifName);

    return { gif: `data:image/gif;base64,${gif.toString('base64')}` };
};

```

```js
let img = document.createElement("img");
document.body.appendChild(img);
fetch('https://73cfjh04u2.execute-api.eu-west-1.amazonaws.com/default/aperotech1?start=18')
    .then(async response => {
        img.src = (await response.json()).gif
    });
 ```

</details>

