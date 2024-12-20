resource "azurerm_resource_group" "rg" {
  count = var.create_resource_group ? 1 : 0

  location = var.location
  name     = var.resource_group_name
  tags     = try(merge(var.resource_group_tags, var.tags), {})
}

locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.rg[0].name : var.resource_group_name
}

resource "azurerm_virtual_wan" "virtual_wan" {
  location                          = var.location
  name                              = var.virtual_wan_name
  resource_group_name               = local.resource_group_name
  allow_branch_to_branch_traffic    = try(var.allow_branch_to_branch_traffic, true)
  disable_vpn_encryption            = var.disable_vpn_encryption ? false : true
  office365_local_breakout_category = try(var.office365_local_breakout_category, "None")
  tags                              = merge(var.tags, var.virtual_wan_tags)
  type                              = var.type
}

resource "azurerm_virtual_hub" "virtual_hub" {
  for_each = local.virtual_hubs != null && length(local.virtual_hubs) > 0 ? local.virtual_hubs : {}

  location               = each.value.location
  name                   = each.value.name
  resource_group_name    = coalesce(each.value.resource_group, local.resource_group_name)
  address_prefix         = each.value.address_prefix
  hub_routing_preference = each.value.hub_routing_preference
  tags                   = try(each.value.tags, {})
  virtual_wan_id         = azurerm_virtual_wan.virtual_wan.id
}

resource "azurerm_virtual_hub_route_table" "example" {
  for_each = var.virtual_hub_route_tables
  name           = each.value.name
  virtual_hub_id = azurerm_virtual_hub.virtual_hub[each.value.virtual_hub_key].id
  labels         = each.value.labels

  dynamic "route" {
    for_each = each.value.routes

    content {
      name              = route.value.name
      destinations_type = route.value.destinations_type
      destinations      = route.value.destinations
      next_hop_type     = route.value.next_hop_type
      next_hop          = route.value.next_hop
    }
  }
}
