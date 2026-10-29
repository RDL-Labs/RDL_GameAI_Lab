# Default non-food kinds have their own namespace; none is an edible food ID.
# These properties describe the world, not an owner's liking or exchange price.
# Additional kinds are registered by scene data, without changing this table.
const GLOWING_STONE_ITEM=1
const SHELL_ITEM=2
const FEATHER_ITEM=3
const ITEM_KIND_IDS=(GLOWING_STONE_ITEM,SHELL_ITEM,FEATHER_ITEM)
const ITEM_KIND_LABELS=("glowing_stone","shell","feather")
const ITEM_COLORS=("cyan","cream","blue")
const ITEM_SIZES=(.12,.10,.18)
const ITEM_MASSES=(.2,.05,.005)
const ITEM_LIGHT=(.02,0.,0.)
const ITEM_GROUND=UInt8(1)
const ITEM_HELD=UInt8(2)
const ITEM_STORED=UInt8(3)
const ITEM_LOCATIONS=("ground","held","stored")
