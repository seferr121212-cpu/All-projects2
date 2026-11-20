"""Converts Quaternius FBX packs (CC0) to .glb with materials/textures for Godot.
Run: python tools/convert_packs.py <packs_dir> <out_dir>
Each FBX becomes <out_dir>/<pack>/<name>.glb, scaled so 1 unit = 1 m as authored."""
import bpy, sys, os, glob, re

src, out = sys.argv[1], sys.argv[2]
WANT = {
    "Survival": ["Backpack", "Bonfire", "Pot", "Pot_Small", "Pan", "Pan_Small", "Radio", "Compass_Closed", "Compass_Open", "Phone",
                 "WaterBottle_1", "WaterBottle_2", "WaterBottle_3", "Can_Closed", "Can_Open", "Can_Red", "FirstAidKit", "PropaneTank",
                 "GasCan", "Tent", "Torch", "Trashcan", "Matchbox", "WoodLog", "Bandages", "Knife", "Shovel", "Axe", "Raft_Paddle", "Battery_Big"],
    "Farm": ["Barn", "BigBarn", "SmallBarn", "OpenBarn", "ChickenCoop", "Fence", "Fence2", "Silo", "Silo_House", "Well", "Windmill", "TowerWindmill", "WaterTower"],
    "Ships": ["Boat", "BoatWSail", "Lifeboat", "Sail ship", "Viking boat"],
    "Trees": None,  # all
    "Fish": ["Boat", "Dock_Long_NoRope", "Dock_Wide", "FishingRod_Lvl1", "FishingRod_Lvl3", "Tuna", "Clownfish", "BlueTang", "Goldfish", "BlueGoldfish", "Swordfish", "Piranha", "Tetra", "Cowfish", "Turbot"],
}


def pack_key(path):
    for k, name in (("Survival", "Survival"), ("Farm", "Farm"), ("Ships", "Ships"), ("Trees", "Trees"), ("Fish", "Fish")):
        if name in path:
            return k
    return None


for fbx in sorted(glob.glob(os.path.join(src, "**", "FBX", "*.fbx"), recursive=True)):
    key = pack_key(fbx)
    name = os.path.splitext(os.path.basename(fbx))[0]
    want = WANT.get(key)
    if key is None or (want is not None and name not in want):
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    for ob in list(bpy.context.scene.objects):
        if ob.type not in ('MESH',):
            if ob.type != 'ARMATURE':
                bpy.data.objects.remove(ob)
    for mat in bpy.data.materials:  # the FBX exporter wrote opacity 0; force opaque
        if mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    node.inputs['Alpha'].default_value = 1.0
                    for l in list(node.inputs['Alpha'].links):
                        mat.node_tree.links.remove(l)
    if key == "Trees":  # the FBX files carry no texture links: assign by material name
        tex_dir = os.path.join(os.path.dirname(os.path.dirname(fbx)), "Textures")
        for mat in bpy.data.materials:
            cand = {"Bark": "Tree_Bark.jpg", "Birch_Leaves": "Birch_Leaves_Green.png"}.get(mat.name.split(".")[0], mat.name.split(".")[0] + ".png")
            if "Dead" in name:
                cand = {"Bark": "Color Variations/Bark_Dead.png", "Birch_Bark": "Color Variations/Birch_Bark_Dead.png"}.get(mat.name.split(".")[0], cand)
            path = os.path.join(tex_dir, cand)
            if mat.use_nodes and os.path.exists(path):
                tn = mat.node_tree.nodes.new('ShaderNodeTexImage')
                tn.image = bpy.data.images.load(path)
                for node in mat.node_tree.nodes:
                    if node.type == 'BSDF_PRINCIPLED':
                        mat.node_tree.links.new(tn.outputs['Color'], node.inputs['Base Color'])
                        if "Leaves" in mat.name:  # leaf cards: cut out by the texture's alpha
                            mat.node_tree.links.new(tn.outputs['Alpha'], node.inputs['Alpha'])
    d = os.path.join(out, key.lower())
    os.makedirs(d, exist_ok=True)
    safe = re.sub(r"[^A-Za-z0-9_]+", "_", name).strip("_")
    bpy.ops.export_scene.gltf(filepath=os.path.join(d, safe + ".glb"), export_format='GLB', export_materials='EXPORT',
                              export_image_format='AUTO', export_yup=True, export_apply=True)
    print("converted", key, safe)
