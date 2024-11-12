import { config } from './config'
import s3EventConsumer from './consumers/s3EventConsumer';

console.log("Starting S3 Event Consumer...");
s3EventConsumer.start();