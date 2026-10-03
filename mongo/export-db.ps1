# Xuất toàn bộ database fitness (cả dữ liệu) ra một file để gửi cho người khác.
# Chạy trong thư mục mongo:  .\export-db.ps1
# Kết quả: fitness-YYYYMMDD-HHmm.archive.gz

$ErrorActionPreference = "Stop"
$name = "fitness-{0}.archive.gz" -f (Get-Date -Format "yyyyMMdd-HHmm")

docker exec fitness-mongo mongodump --port 27018 --db fitness --gzip --archive=/tmp/fitness.archive.gz
docker cp "fitness-mongo:/tmp/fitness.archive.gz" ".\$name"
docker exec fitness-mongo rm /tmp/fitness.archive.gz

Write-Host "Đã xuất: $name"
