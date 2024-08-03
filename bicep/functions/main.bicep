@export()
func createIdentityObject(
  isSystemAssignedIdentityEnabled bool,
  userAssignedIdentities {
    name: string
    resourceGroupName: string?
    subscriptionId: string?
  }[]
) object => union({
  type: (isSystemAssignedIdentityEnabled ? (empty(userAssignedIdentities) ? 'SystemAssigned' : 'SystemAssigned, UserAssigned') : (empty(userAssignedIdentities) ? 'None' : 'UserAssigned'))
}, (empty(userAssignedIdentities) ? {} : {
  userAssignedIdentities: toObject(
    userAssignedIdentities,
    identity => resourceId(
      (identity.?subscriptionId ?? subscription().subscriptionId),
      (identity.?resourceGroupName ?? resourceGroup().name),
      'Microsoft.ManagedIdentity/userAssignedIdentities',
      identity.name
    ),
    identity => {}
  )
}))
