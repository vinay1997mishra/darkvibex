#!/bin/bash
# DarkVibeX vehicle-entry videos -> Cloudflare R2 (DIRECT, no Worker in playback path)
# Usage:
#   export R2_ACCOUNT_ID=...
#   export R2_ACCESS_KEY_ID=...
#   export R2_SECRET_ACCESS_KEY=...
#   export R2_BUCKET=darkvibex-files   # existing bucket, already bound to Worker as FILES
#   bash cloudflare-r2-upload.sh
# Requires: aws CLI (awscli). R2 is S3-compatible.
# Total: 14 MP4s, ~157 MB. Free tier: 10 GB storage, zero egress.
set -euo pipefail
: "${R2_ACCOUNT_ID:?set R2_ACCOUNT_ID}"
: "${R2_ACCESS_KEY_ID:?set R2_ACCESS_KEY_ID}"
: "${R2_SECRET_ACCESS_KEY:?set R2_SECRET_ACCESS_KEY}"
R2_BUCKET="${R2_BUCKET:-darkvibex-files}"
ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
SRC="$(cd "$(dirname "$0")/videos" && pwd)"

upload() {
  # $1 = local filename, $2 = R2 key
  aws --endpoint-url "$ENDPOINT" s3 cp "$SRC/$1" "s3://$R2_BUCKET/$2" \
    --content-type video/mp4 --cache-control "public, max-age=31536000"
  echo "OK $2"
}

upload "media-generation-vip5-deer-superpower-0-ffb877e8-d2f5-4801-9edb-1cf2d632d369.mp4"  "vehicles/vip5-deer.mp4"
upload "media-generation-vip6-wolf-superpower-0-f4092fd8-b6f2-4301-a37c-08c87b19dea7.mp4"  "vehicles/vip6-wolf.mp4"
upload "media-generation-vip7-eagle-superpower-0-6aa08eef-0bc5-4eab-85e1-1c83eac84732.mp4" "vehicles/vip7-eagle.mp4"
upload "media-generation-vip8-panther-superpower-0-0a0d1da0-6d2d-4125-89f9-bbebd0f3bbbf.mp4" "vehicles/vip8-panther.mp4"
upload "media-generation-vip9-cobra-superpower-0-b39a4267-c970-4cac-8254-621d22ec7fcf.mp4" "vehicles/vip9-cobra.mp4"
upload "media-generation-vip10-lion-superpower-0-e9243c51-2b33-4742-947f-06f3b09d7b6f.mp4" "vehicles/vip10-lion.mp4"
upload "media-generation-vip11-tiger-premium-0-243fd86c-1899-47c6-ba46-cd0aae7c6266.mp4" "vehicles/vip11-tiger.mp4"
upload "media-generation-vip12-mammoth-premium-0-41b4160e-85fd-4b73-8f30-166576579a85.mp4" "vehicles/vip12-mammoth.mp4"
upload "media-generation-vip13-gorilla-premium-0-5e0741a5-605c-49e6-b472-50773a3c75a2.mp4" "vehicles/vip13-gorilla.mp4"
upload "media-generation-vip14-bear-premium-0-3679e073-39f9-40fd-9582-b58e2a03dcec.mp4" "vehicles/vip14-bear.mp4"
upload "media-generation-vip15-kraken-premium-0-3eab4c0a-43c0-4c1b-b923-44353f93b938.mp4" "vehicles/vip15-kraken.mp4"
upload "media-generation-vip16-leviathan-superpremium-0-b26ea4d0-6ba8-4ef0-b87e-b47acf3d5a22.mp4" "vehicles/vip16-leviathan.mp4"
upload "media-generation-vip17-phoenix-superpremium-0-17afdbe2-e126-4aad-9342-654fad7e499d.mp4" "vehicles/vip17-phoenix.mp4"
upload "media-generation-vip18-dragon-superpremium-0-e260a266-1eee-4158-b306-a98657b28d62.mp4" "vehicles/vip18-dragon.mp4"

echo "Done. Public URL pattern (with custom domain, e.g. cdn.example.com):"
echo "  https://cdn.example.com/vehicles/vip17-phoenix.mp4"
echo "Set that URL as active_vehicle_video_key in the app/worker."
