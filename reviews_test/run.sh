#!/bin/bash
#
# Possible options:
#
# --domain or -d, "Domain name of the website"
# --api_key or -k, "API key for access"
# --channel or -c, "Channel for test: all, movie, game, app, website, tv, show, book, music"
# --limit or -l, "Number of product for test-- all or any number"
# --movie_element_spec, "Relative path to the movie element specification file"
# --game_element_spec, "Relative path to the game element specification file"
# --website_element_spec, "Relative path to the website element specification file"
# --tv_element_spec, "Relative path to the tv element specification file"
# --show_element_spec, "Relative path to the show element specification file"
# --book_element_spec, "Relative path to the book element specification file"
# --music_element_spec, "Relative path to the music element specification file"
#
# This command executes the test
#
 ruby ./lib/xml_element_validation.rb
