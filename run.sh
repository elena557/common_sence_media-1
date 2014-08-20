#!/bin/bash
#
# Possible options:
#
# --domain or -d, "Domain name of the website"
# --api-key or -k, "API key for access"
# --element or -e, "Element name for API request"
# --channel or -c, "Channel parameter for API request"
# --check-inside-node, "Specify symbol or text which you would like to test inside every feed"
# --check-ampersand = true, "Check ampersand inside every feed"
# --limit or -l, "Number of product for test-- all or any number"
# --log-file-folder, "Relative to the log file"
# --input-spec-file or -i, "Relative path to the element specification file"
# --output-report-directory or -o, "The output directory for report file",
#
# This command executes the test
#
# Commands to run review feeds test for each channel
# ruby  ./lib/xml_element_validation.rb -e reviews -c app -i ./etc/reviews_app.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c book -i ./etc/reviews_book.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c game -i ./etc/reviews_game.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c movie -i ./etc/reviews_movie.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c music -i ./etc/reviews_music.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c show -i ./etc/reviews_show.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c tv -i ./etc/reviews_tv.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c website -i ./etc/reviews_website.json
#
# Command to run video feed test
# ruby  ./lib/xml_element_validation.rb -e videos  -k 404da1a207199d7ed5d9f0d887827982 -i ./etc/video.json
#
#
# Commands to run review feeds test for each channel
# ruby  ./lib/xml_element_validation.rb -e reviews -c app -k 3d6cd25d4da8a681eca4c9d87d5c206f -i ./etc/reviews_app_with_stat.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c book -k 3d6cd25d4da8a681eca4c9d87d5c206f -i ./etc/reviews_book_with_stat.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c game -k 3d6cd25d4da8a681eca4c9d87d5c206f  -i ./etc/reviews_game_with_stat.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c movie -k 3d6cd25d4da8a681eca4c9d87d5c206f -i ./etc/reviews_movie_with_stat.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c music -k 3d6cd25d4da8a681eca4c9d87d5c206f -i ./etc/reviews_music_with_stat.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c show -k 3d6cd25d4da8a681eca4c9d87d5c206f -i ./etc/reviews_show_with_stat.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c tv -k 3d6cd25d4da8a681eca4c9d87d5c206f  -i ./etc/reviews_tv_with_stat.json
# ruby  ./lib/xml_element_validation.rb -e reviews -c website  -k 3d6cd25d4da8a681eca4c9d87d5c206f -i ./etc/reviews_website_with_stat.json
#
#
# Commands to check some date inside feeds
# ruby  ./lib/xml_element_validation.rb -e reviews -c website --check-inside-node '1969-12-31' -k 3d6cd25d4da8a681eca4c9d87d5c206f -l 2 -i ./etc/reviews_website_with_stat.json
#
#
# Commands to check some special character inside feeds
# ruby  ./lib/xml_element_validation.rb -e reviews -c website --check-ampersand=true -k 3d6cd25d4da8a681eca4c9d87d5c206f -l 2 -i ./etc/reviews_website_with_stat.json
