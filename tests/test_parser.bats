#!/usr/bin/env bats

setup() {
    . src/core/fetcher.sh
    . src/plugins/sportsonline.sh
}

@test "parse_prog_txt extracts events correctly" {
    sample="15:00   Chelsea x Nottingham Forest | https://v3.sportssonline.click/channels/hd/hd1.php"
    result=$(echo "$sample" | plugin_parse)
    [ "$result" = "15:00|Chelsea x Nottingham Forest|HD1|https://v3.sportssonline.click/channels/hd/hd1.php" ]
}
