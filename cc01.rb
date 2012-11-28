#!/usr/bin/env ruby

require 'aws-sdk'
require 'digest/sha1'
require 'exifr'

# read authentication details
require './aws-config'
# aws-config.rb:
# #!/usr/bin/env ruby
# @aws_access_key = "AWS_ACCESS_KEY"
# @aws_secret_key = "AWS_SECRET_KEY"
# @region = "us-west-2"

AWS.config(
  :access_key_id => @aws_access_key,
  :secret_access_key => @aws_secret_key,
  :dynamo_db_endpoint => "dynamodb.#{@region}.amazonaws.com",
  )

name = 'mwhiteley'
problem = "#{name}-reinvent-cc01"

s3 = AWS::S3.new
dynamo_db = AWS::DynamoDB.new

# create S3 bucket
bucket = s3.buckets[problem]
unless bucket.exists?
  s3.buckets.create(problem)
end

# create DynamoDB table
table = dynamo_db.tables[problem]
unless table.exists?
  table = dynamo_db.tables.create(problem, 10, 5)
  sleep 1 while table.status == :creating
end
table.hash_key = [:id, :string]

ARGV.each do |filename|
  begin
    exif = EXIFR::JPEG.new(filename)
  rescue EOFError
    puts "#{filename} is not a JPEG"
  end

  sha = Digest::SHA1.hexdigest(filename)
  obj = bucket.objects[sha]
  if obj.exists?
    puts "#{filename} exists skipping ..."
    continue
  end

  puts "uploading #{filename} ..."
  obj.write(Pathname.new(filename))

  item = table.items.create(
    'id' => sha,
    'filename' => filename,
    'width' => exif.width,
    'height' => exif.height,
    'bits' => exif.bits,
  )

  puts "metadata written for #{item.hash_value}"
end
