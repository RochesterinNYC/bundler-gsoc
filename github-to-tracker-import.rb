#!/usr/bin/env ruby
require 'octokit'
require 'json'

@tracker_api_key = ENV["PIVOTAL_TRACKER_API_KEY"]
@project_id = ENV["BUNDLER_PROJECT_ID"]
@requester_id = ENV["BUNDLER_REQUESTER_ID"]

def get_all_stories
  payload = {
    limit: 1000
  }.to_json

  all_stories_uri = URI.parse("https://www.pivotaltracker.com/services/v5/projects/#{@project_id}/stories")

  request = Net::HTTP::Get.new(all_stories_uri)
  request.body = payload
  request['Content-Type'] = 'application/json'
  request['X-TrackerToken'] = @tracker_api_key

  response = Net::HTTP.start(all_stories_uri.hostname, all_stories_uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  raise response.message if response.code != '200'
  
  puts "Got all stories" 

  JSON.parse(response.body)
end

def delete_all_stories(story_ids)
  story_ids.each do |story_id|
    delete_stories_uri = URI.parse("https://www.pivotaltracker.com/services/v5/projects/#{@project_id}/stories/#{story_id}")

    request = Net::HTTP::Delete.new(delete_stories_uri)
    request['Content-Type'] = 'application/json'
    request['X-TrackerToken'] = @tracker_api_key

    response = Net::HTTP.start(delete_stories_uri.hostname, delete_stories_uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise response.message if response.code != '204'
  end
  
  puts "Deleted all stories" 
end

def create_story(title, description, labels = [])
  label_api_objs = labels.map { |label| { name: label } } 
  payload = {
    name: title,
    description: description,
    requested_by_id: @requester_id,
    story_type: 'feature',
    labels: label_api_objs 
  }.to_json

  create_story_uri = URI.parse("https://www.pivotaltracker.com/services/v5/projects/#{@project_id}/stories")

  request = Net::HTTP::Post.new(create_story_uri)
  request.body = payload
  request['Content-Type'] = 'application/json'
  request['X-TrackerToken'] = @tracker_api_key

  response = Net::HTTP.start(create_story_uri.hostname, create_story_uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  raise response.message if response.code != '200'
  
  puts "Created story for #{title}" 

  response
end

Octokit.configure do |c|
  c.access_token = ENV["GITHUB_API_TOKEN"]
  c.auto_paginate = true
end

all_stories = get_all_stories
if ENV["REFILL_TRACKER_BOARD"]
  all_story_ids = all_stories.map{|story| story['id']} 
  delete_all_stories(all_story_ids)
end

# Bundler
# Get all open issues
repo_identifier = "bundler/bundler"
open_issues_prs = Octokit.list_issues(repo_identifier, state: 'open')

# Sort into issues and pull requests
open_issues = open_issues_prs.select{|issue| !issue.pull_request?}
open_prs = open_issues_prs.select{|issue| issue.pull_request?}

# Query tracker project for stories and create list of html_urls that have been handled already
github_html_urls = all_stories.map{|story| /.*(https:\/\/github.com\/[\w]+\/[\w]+\/(issues|pulls)\/4059).*/.match(story['description']) }

#Create story for each issue or pr not already in the tracker story
open_issues.each do |issue|
  story_title = "Issue: #{issue.title}"
  story_description = "#{issue.html_url}"
  story_labels = issue.labels.map{|label| label.name}
  create_story(story_title, story_description, story_labels + ['issue']) unless github_html_urls.include? issue.html_url
end

open_prs.each do |pr|
  story_title = "PR: #{pr.title}"
  story_description = "#{pr.html_url}"
  story_labels = pr.labels.map{|label| label.name}
  create_story(story_title, story_description, story_labels + ['pull-request']) unless github_html_urls.include? pr.html_url

end
