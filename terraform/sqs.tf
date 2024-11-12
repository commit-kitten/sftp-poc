# Generate a unique SQS queue for S3 events
resource "aws_sqs_queue" "s3_event_queue" {
  name = "s3-event-queue-${random_id.bucket_suffix.hex}"
}

# Allow S3 to send events to SQS
resource "aws_sqs_queue_policy" "s3_event_queue_policy" {
  queue_url = aws_sqs_queue.s3_event_queue.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action    = "SQS:SendMessage",
        Resource  = aws_sqs_queue.s3_event_queue.arn,
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.sftp_destination_bucket.arn
          }
        }
      }
    ]
  })
}

# S3 bucket notification for new files in clearing_files folder
resource "aws_s3_bucket_notification" "clearing_files_notification" {
  bucket = aws_s3_bucket.sftp_destination_bucket.id

  queue {
    queue_arn     = aws_sqs_queue.s3_event_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".json"
    filter_prefix = "outgoing/clearing_files/"
  }
}

# Output the SQS queue URL for easy reference in GitHub
output "s3_event_queue_url" {
  value       = aws_sqs_queue.s3_event_queue.id
  description = "The URL of the S3 event SQS queue."
}
