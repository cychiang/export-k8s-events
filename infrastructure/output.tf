output "firehose_s3_stream_name" {
  value = aws_kinesis_firehose_delivery_stream.firehose_s3_stream.name
}
