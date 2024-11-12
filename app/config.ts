import dotenv from 'dotenv';
dotenv.config();

export const config = {
    BUCKET_NAME: process.env.BUCKET_NAME!,
    AWS_REGION: process.env.AWS_REGION!,
    AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID!,
    AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY!,
    S3_EVENT_QUEUE_URL: process.env.S3_EVENT_QUEUE_URL!
};