# -*- coding: utf-8 -*-
"""Tüm pixel art'ı yeniden üretir: python3 tools/art/build_all.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chars, props, tiles, backgrounds, story, foreground, decor, houses, fx_extra, story2, title, chapter5, normals

chars.kerem_sheet(); chars.echo_sheets(); chars.npc_sheets()
from common import save, sheet
save(props.brazier(), "props/brazier.png")
save(sheet([props.flame(i / 8) for i in range(8)]), "props/flame.png")
save(props.lamp_held(), "props/lamp_held.png")
save(sheet([props.lamp_flame(i / 4) for i in range(4)]), "props/lamp_flame.png")
props.pickups(); props.crate(); props.mirror_stand(); props.lens_seal(); props.winch()
props.mechanism(); props.big_bell(); props.boat(); props.furniture(); props.glow(); props.ui_icons()
tiles.generate()
backgrounds.generate()
story.generate()
foreground.generate()
decor.generate()
houses.generate()
fx_extra.generate()
story2.generate()
title.generate()
chapter5.generate()
normals.generate()
print("art/ hazır")
