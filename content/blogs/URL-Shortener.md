---
title: "URL Shortener"
date: 2020-12-07T17:16:21+08:00
url: /blog/Url-shortener/
image: https://simpleicons.org/icons/fujitsu.svg
description: A simple app that is build on Cloudflare Workers using Short.io API.
tags:
  - serverless
  - cloudflare 
---

## What's it

URL-Shortener is a simple app that is build on Cloudflare Workers using Short.io API.

[![index](https://raw.githubusercontent.com/francis-du/url-shortener/main/src/static/img/index.png)](https://short.francis.run/?link=https%3A%2F%2Ffrancis.run)

## How to use

[![Deploy to Cloudflare Workers](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/francis-du/url-shortener)

### Web UI

- Open Website `https://short.francis.run`

- Paste the long link you want to shorten.

- Click the Go button to generate a short link.

### Get request

- Request Url `https://short.francis.run`

- Request parameters and return response data

|  parameters  | description  | required |
|  ----  | ----  | ------- | 
| ?link=""  | link, which you want to shorten| Y|
| ?api="true" | Return json data - Required| Y |
| ?title="" |title of created URL to be shown in short.cm admin panel | N |
| ?path""  | optional path part of newly created link. If empty - it will be generated automatically | N |