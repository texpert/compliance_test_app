#!/usr/bin/env ruby
# frozen_string_literal: true

# convert_backtick_docs.rb
# Replace backtick-wrapped `docs/...*.md` references in Markdown files under docs/
# with relative Markdown links using visible basename and computed relative path.

require 'pathname'

REPO_ROOT = Pathname.new(Dir.pwd).realpath

Dir.glob('docs/**/*.md').each do |f|
  path = Pathname.new(f)
  text = path.read
  new_text = text.dup

  new_text.gsub!(/`docs\/([^`]+?\.md)`/) do |m|
    target_rel = Regexp.last_match(1)
    target_abs = (REPO_ROOT + 'docs' + target_rel)
    unless target_abs.exist?
      # skip replacement if target doesn't exist
      puts "SKIP: #{f} -> docs/#{target_rel} (missing)"
      next m
    end
    rel = target_abs.realpath.relative_path_from(path.dirname.realpath).to_s
    rel = rel.gsub('\\', '/')
    basename = File.basename(target_rel)
    "[#{basename}](#{rel})"
  end

  if new_text != text
    path.write(new_text)
    puts "Updated: #{f}"
  end
end
