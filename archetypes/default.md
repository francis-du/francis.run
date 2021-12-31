---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
url: /{{ .Name }}/
image: /img/{{ .Name }}.jpg
description: "{{ replace .Name "-" " " | title }}"
tags:
 -
---