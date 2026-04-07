#!/usr/bin/env ruby
# frozen_string_literal: true
#
# scripts/bump_version.rb
#
# Increments the version in pubspec.yaml based on the latest Git semver tag.
#
# USAGE
#   ruby scripts/bump_version.rb              # auto-detect bump type from tag
#   ruby scripts/bump_version.rb --patch      # force patch bump  (1.0.3 → 1.0.4)
#   ruby scripts/bump_version.rb --minor      # force minor bump  (1.0.3 → 1.1.0)
#   ruby scripts/bump_version.rb --major      # force major bump  (1.0.3 → 2.0.0)
#   ruby scripts/bump_version.rb --tag        # also create a new git tag
#
# The script always increments the build number (the +NN part) by 1.
#
# ─────────────────────────────────────────────────────────────────────────────

require "optparse"

PUBSPEC = File.expand_path("../pubspec.yaml", __dir__)

# ── Parse CLI options ──────────────────────────────────────────────────────────
options = { bump: :auto, tag: false }
OptionParser.new do |opts|
  opts.on("--patch")  { options[:bump] = :patch }
  opts.on("--minor")  { options[:bump] = :minor }
  opts.on("--major")  { options[:bump] = :major }
  opts.on("--tag")    { options[:tag]  = true   }
end.parse!

# ── Helpers ────────────────────────────────────────────────────────────────────
def run(cmd)
  result = `#{cmd} 2>&1`.strip
  raise "Command failed: #{cmd}\n#{result}" unless $?.success?
  result
end

def parse_pubspec_version(pubspec_path)
  content = File.read(pubspec_path)
  m = content.match(/^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)/)
  abort "❌ Cannot parse version from pubspec.yaml" unless m
  { major: m[1].to_i, minor: m[2].to_i, patch: m[3].to_i, build: m[4].to_i,
    content: content }
end

def write_version(pubspec_path, v)
  ver_string = "#{v[:major]}.#{v[:minor]}.#{v[:patch]}+#{v[:build]}"
  updated = v[:content].sub(/^version:\s*.+$/, "version: #{ver_string}")
  File.write(pubspec_path, updated)
  ver_string
end

# ── Read current version ───────────────────────────────────────────────────────
v = parse_pubspec_version(PUBSPEC)
puts "📦 Current version: #{v[:major]}.#{v[:minor]}.#{v[:patch]}+#{v[:build]}"

# ── Determine bump type from latest tag (auto mode) ───────────────────────────
if options[:bump] == :auto
  begin
    latest_tag = run("git describe --tags --match 'v*' --abbrev=0")
    puts "🏷  Latest tag: #{latest_tag}"

    # Compare tag version to pubspec
    m = latest_tag.match(/v(\d+)\.(\d+)\.(\d+)/)
    if m
      tag_major, tag_minor, tag_patch = m[1].to_i, m[2].to_i, m[3].to_i
      if tag_major > v[:major]
        options[:bump] = :major
      elsif tag_minor > v[:minor]
        options[:bump] = :minor
      else
        options[:bump] = :patch
      end
    else
      options[:bump] = :patch
    end
  rescue
    puts "⚠️  No git tags found – defaulting to patch bump"
    options[:bump] = :patch
  end
end

# ── Apply bump ────────────────────────────────────────────────────────────────
case options[:bump]
when :major
  v[:major] += 1
  v[:minor]  = 0
  v[:patch]  = 0
when :minor
  v[:minor] += 1
  v[:patch]  = 0
when :patch
  v[:patch] += 1
end
v[:build] += 1

new_version_string = write_version(PUBSPEC, v)
puts "✅ New version: #{new_version_string}"

# ── Optionally create git tag ─────────────────────────────────────────────────
if options[:tag]
  semver = "v#{v[:major]}.#{v[:minor]}.#{v[:patch]}"
  run("git add #{PUBSPEC}")
  run("git commit -m 'chore: bump version to #{new_version_string}'")
  run("git tag #{semver}")
  puts "🏷  Created git tag: #{semver}"
  puts "👉 Push with: git push origin #{semver}"
end
