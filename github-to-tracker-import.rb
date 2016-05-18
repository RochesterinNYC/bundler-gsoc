#!/usr/bin/env ruby
require 'octokit'
require 'json'

@tracker_api_key = ENV["PIVOTAL_TRACKER_API_KEY"]
@project_id = ENV["BUNDLER_PROJECT_ID"].to_i
@requester_id = ENV["BUNDLER_REQUESTER_ID"].to_i

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

  raise (response.message + response.body) if response.code != '200'
  
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

    raise (response.message + response.body) if response.code != '204'
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

  raise (response.body + response.message) if response.code != '200'
  
  puts "Created story for #{title}" 

  response
end

def update_labels_for_story(id, labels)
  label_api_objs = labels.map { |label| { name: label } }
  payload = {
    labels: label_api_objs
  }.to_json

  update_story_uri = URI.parse("https://www.pivotaltracker.com/services/v5/projects/#{@project_id}/stories/#{id}")

  request = Net::HTTP::Put.new(update_story_uri)
  request.body = payload
  request['Content-Type'] = 'application/json'
  request['X-TrackerToken'] = @tracker_api_key

  response = Net::HTTP.start(update_story_uri.hostname, update_story_uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  raise (response.body + response.message) if response.code != '200'

  puts "Updated labels (to #{labels}) for tracker story with id #{id}"
end

Octokit.configure do |c|
  c.access_token = ENV["GITHUB_API_TOKEN"]
  c.auto_paginate = true
end

if ENV["REFILL_TRACKER_BOARD"]
  all_story_ids = get_all_stories.map{|story| story['id']}
  delete_all_stories(all_story_ids)
end

# Bundler
# Get all open issues
repo_identifier = "bundler/bundler"
open_issues_prs = Octokit.list_issues(repo_identifier, state: 'open')

# Sort into issues and pull requests
open_issues = open_issues_prs.select{|issue| !issue.pull_request?}
open_prs = open_issues_prs.select{|issue| issue.pull_request?}

def get_html_url_from_story(story)
  /.*(https:\/\/github.com\/[\w]+\/[\w]+\/(issues|pull)\/\d+).*/.match(story['description'])
  $1
end

# Query tracker project for stories and create list of html_urls that have been handled already
all_stories = get_all_stories
url_to_story_mapping = Hash[all_stories.collect{|story| [get_html_url_from_story(story), story] }]
github_html_urls = url_to_story_mapping.keys

#Create story for each issue or pr not already in the tracker story
open_issues.each do |issue|
  story_title = "Issue: #{issue.title}"
  story_description = "#{issue.html_url}"
  story_labels = issue.labels.map{|label| label.name.downcase} + ['issue']

  if !github_html_urls.include? issue.html_url
    create_story(story_title, story_description, story_labels)
  else
    tracker_story = url_to_story_mapping[issue.html_url]
    current_tracker_labels = tracker_story['labels'].map{|label| label['name']}

    #update labels of tracker story if not the same
    if story_labels.sort != current_tracker_labels.sort
      update_labels_for_story(tracker_story['id'], story_labels)
    end
  end
end

open_prs.each do |pr|
  story_title = "PR: #{pr.title}"
  story_description = "#{pr.html_url}"
  story_labels = pr.labels.map{|label| label.name.downcase} + ['pull-request']

  if !github_html_urls.include? pr.html_url
    create_story(story_title, story_description, story_labels)
  else
    tracker_story = url_to_story_mapping[pr.html_url]
    current_tracker_labels = tracker_story["labels"].map{|label| label['name']}

    #update labels of tracker story if not the same
    if story_labels.sort != current_tracker_labels.sort
      update_labels_for_story(tracker_story['id'], story_labels)
    end
  end
end
