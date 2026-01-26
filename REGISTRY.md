# Agent Registry

This file contains a registry of all Raspberry Pi images created with embedded Open Horizon components. Each entry represents a unique agent configuration with its deployment details.

## Registry Format

Each agent configuration includes:
- **Created**: ISO timestamp of when the image was created
- **Open Horizon Version**: Version of Open Horizon components installed
- **Exchange URL**: Open Horizon exchange URL and organization (or "none" if not configured)
- **Node JSON**: Custom node.json configuration file used (or "default")
- **Wi-Fi SSID**: Wi-Fi network configured (or "none" if not configured)
- **Base Image**: Original Raspberry Pi OS image filename
- **Output Image**: Generated custom image filename
- **Status**: Current status (created|deployed|retired)

## Agent Configurations

## Agent Configuration: 1769378284-bcfbff97

- **Created**: 2026-01-25T21:58:04Z
- **Open Horizon Version**: 2.31.0
- **Exchange URL**: https://exchange.example.com (org: myorg)
- **Node JSON**: custom-node.json
- **Wi-Fi SSID**: TestNetwork
- **Base Image**: test-raspios.img
- **Output Image**: test-custom-full.img
- **Status**: created

## Agent Configuration: 1769378294-5335528f

- **Created**: 2026-01-25T21:58:14Z
- **Open Horizon Version**: 2.32.0
- **Exchange URL**: none
- **Node JSON**: default
- **Wi-Fi SSID**: none
- **Base Image**: test-raspios.img
- **Output Image**: test-custom-simple.img
- **Status**: created

## Agent Configuration: 1769378589-0fa4782f

- **Created**: 2026-01-25T22:03:09Z
- **Open Horizon Version**: 2.30.0
- **Exchange URL**: none
- **Node JSON**: default
- **Wi-Fi SSID**: none
- **Base Image**: test-image.img
- **Output Image**: test-output.img
- **Status**: created