#!/bin/bash
kinit -n @FEDORAPROJECT.ORG -c FILE:${HOME}/armor.ccache
kinit -T FILE:${HOME}/armor.ccache cqi@FEDORAPROJECT.ORG
