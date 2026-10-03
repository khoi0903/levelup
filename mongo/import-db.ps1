# Nhập file .archive.gz nhận được vào MongoDB của máy mình.
# Chạy trong thư mục mongo (container fitness-mongo phải đang chạy):
#   .\import-db.ps1 .\fitness-20261120-1530.archive.gz
# Lưu ý: --drop XÓA dữ liệu fitness hiện có trên máy rồi thay bằng dữ liệu trong file.

param([Parameter(Mandatory = $true)][string]$File)
$ErrorActionPreference = "Stop"

docker cp $File "fitness-mongo:/tmp/fitness.archive.gz"
docker exec fitness-mongo mongorestore --port 27018 --gzip --archive=/tmp/fitness.archive.gz --drop
docker exec fitness-mongo rm /tmp/fitness.archive.gz

Write-Host "Đã nhập xong vào database fitness."
