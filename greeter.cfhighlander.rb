CfhighlanderTemplate do

  Description "Greeter Service - (#{component_name}@#{component_version})"

  Parameters do
    ComponentParam 'VPCId'
    ComponentParam 'SubnetIds'
    ComponentParam 'GreeterServiceTag'
    
  end

  Component template: 'ecs-v2@0.2.0', name: 'ecs', render: Inline, config: {
    cluster_name: '${EnvironmentName}-services',
    fargate_only_cluster: true
  } do
    parameter name: 'ContainerInsights', value: 'disabled'
    parameter name: 'AvailabilityZones', value: 3
    parameter name: 'VPCId', value: Ref('VPCId')
  end

  Component template: 'fargate-v2', name: 'greeter-service', render: Inline, config: {
    platform_version: '1.4.0',
    cpu: 1024,
    memory: 2048,
    task_definition: {
      greeter: {
        repo: 'repo',
        image: 'nginx',
        tag_param: 'GreeterVersion'
      }
    }
  } do
    parameter name: 'VPCId', value: Ref('VPCId')
    parameter name: 'SubnetIds', value: Ref('SubnetIds')
    parameter name: 'DesiredCount', value: 1
    parameter name: 'MinimumHealthyPercent', value: 100
    parameter name: 'MaximumPercent', value: 200
    parameter name: 'EnableScaling', value: false
    parameter name: 'greeterserviceTaskGreeterVersion', value: Ref('GreeterServiceTag')
  end

end