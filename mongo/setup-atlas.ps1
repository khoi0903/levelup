# Tạo collection, validator, index và nạp dữ liệu mẫu lên MongoDB Atlas (hoặc MongoDB bất kỳ).
# Dùng lại init.js + load-seed.js như docker compose, chạy bằng image mongo:8.0 (cần Docker đang chạy).
# Chạy lại nhiều lần vẫn an toàn (collection có rồi thì chỉ cập nhật validator, index; dữ liệu mẫu là upsert).
#
#   cd mongo
#   .\setup-atlas.ps1 "mongodb+srv://<user>:<mật khẩu>@<cluster>.mongodb.net/fitness?retryWrites=true&w=majority"
#
# Chuỗi kết nối chứa mật khẩu: không commit, không dán vào chat.

param([Parameter(Mandatory = $true)][string]$Uri)
$ErrorActionPreference = "Stop"

$here = $PSScriptRoot
docker run --rm `
    -v "${here}\init.js:/scripts/init.js:ro" `
    -v "${here}\load-seed.js:/scripts/load-seed.js:ro" `
    -v "${here}\cv-configs.json:/scripts/cv-configs.json:ro" `
    -v "${here}\seed:/seed:ro" `
    mongo:8.0 mongosh $Uri /scripts/init.js /scripts/load-seed.js

Write-Host "Xong: database fitness trên Atlas đã có collection và dữ liệu mẫu."
