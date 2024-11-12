import { GetObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { Message, SQSClient } from "@aws-sdk/client-sqs";

import { Consumer } from 'sqs-consumer';
import { config } from '../config';

const sqsClient = new SQSClient({ region: config.AWS_REGION });
const s3Client = new S3Client({ region: config.AWS_REGION });

async function processS3EventMessage(message: Message) {
    if (message.Body) {
        const s3Event = JSON.parse(message.Body);
        if (s3Event?.Event === "s3:TestEvent") {
            console.log("Received a test event, skipping.");
            return;
        }

        if (s3Event.Records) {
            for (const record of s3Event.Records) {
                const bucketName = record.s3.bucket.name;
                const objectKey = decodeURIComponent(record.s3.object.key.replace(/\+/g, " "));

                // Filter for clearing_files
                if (objectKey.startsWith("outgoing/clearing_files/")) {
                    const fileName = objectKey.split('/').pop();
                    console.log(`New clearing file: ${fileName}`);

                    const getObjectCommand = new GetObjectCommand({ Bucket: bucketName, Key: objectKey });

                    try {
                        const s3Response = await s3Client.send(getObjectCommand);
                        const body = s3Response.Body;
                        if (body?.transformToString) {
                            const fileContent = await body.transformToString();
                            const jsonData = JSON.parse(fileContent);

                            console.log("Parsed JSON content:", jsonData);
                        } else {
                            console.error("Body does not support transformToString.");
                        }
                    } catch (error) {
                        console.error(`Error retrieving object ${objectKey} from bucket ${bucketName}:`, error);
                    }
                } else {
                    console.log(`Ignoring file outside clearing_files: ${objectKey}`);
                }
            }
        }
    }
}

const s3EventConsumer = Consumer.create({
    queueUrl: config.S3_EVENT_QUEUE_URL,
    handleMessage: async (message) => {
        await processS3EventMessage(message);
    },
    sqs: sqsClient,
});

s3EventConsumer.on('error', (err) => {
    console.error(err.message);
});

s3EventConsumer.on('processing_error', (err) => {
    console.error(err.message);
});

export default s3EventConsumer;