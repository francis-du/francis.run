---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
draft: false
url: /{{ .Name }}/
image: /img/{{ .Name }}.jpg
description: "{{ replace .Name "-" " " | title }}"
tags:
 -
---