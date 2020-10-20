
    load('/Users/aaronwalker/.chefdk/gem/ruby/2.5.0/gems/cfhighlander-0.12.1/lib/../cfndsl_ext/iam_helper.rb')

    load('/Users/aaronwalker/.chefdk/gem/ruby/2.5.0/gems/cfhighlander-0.12.1/lib/../cfndsl_ext/lambda_helper.rb')

    load('/Users/aaronwalker/.cfhighlander/components/lib-iam/0.1.0/ext/cfndsl/role.rb')

    load('/Users/aaronwalker/.cfhighlander/components/lib-ec2/0.1.0/ext/cfndsl/security_group.rb')

CloudFormation do
  # cfhl meta: cfndsl_version=1.0.2
  fargate_only_cluster = external_parameters.fetch(:fargate_only_cluster, nil)
  ecs_agent_config = external_parameters.fetch(:ecs_agent_config, nil)
  iam_policies = external_parameters.fetch(:iam_policies, nil)
  dain_hook_iam_policies = external_parameters.fetch(:dain_hook_iam_policies, nil)
  dain_hook_topic_iam_policies = external_parameters.fetch(:dain_hook_topic_iam_policies, nil)
  ecs_scaling_iam_policies = external_parameters.fetch(:ecs_scaling_iam_policies, nil)
  cluster_name = external_parameters.fetch(:cluster_name, nil)
  fargate_only_cluster = external_parameters.fetch(:fargate_only_cluster, nil)
  nested_component = external_parameters.fetch(:nested_component, nil)
  component_version = external_parameters.fetch(:component_version, nil)
  component_name = external_parameters.fetch(:component_name, nil)
  template_name = external_parameters.fetch(:template_name, nil)
  template_version = external_parameters.fetch(:template_version, nil)
  template_dir = external_parameters.fetch(:template_dir, nil)
  description = external_parameters.fetch(:description, nil)

  # render subcomponents


  
		  ecs_tags = []
		  ecs_tags << { Key: 'Name', Value: FnSub("${EnvironmentName}-#{external_parameters[:component_name]}") }
		  ecs_tags << { Key: 'Environment', Value: Ref(:EnvironmentName) }
		  ecs_tags << { Key: 'EnvironmentType', Value: Ref(:EnvironmentType) }
		  
		  cluster_name = external_parameters.fetch(:cluster_name, '')
		  
		  ECS_Cluster(:EcsCluster) {
		    ClusterName FnSub(cluster_name) unless cluster_name.empty?
		    ClusterSetting({ Name: 'containerInsights', Value: Ref(:ContainerInsights) })
		    Tags ecs_tags
		  }
		  
		  Output(:EcsCluster) {
		    Value(Ref(:EcsCluster))
		    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-EcsCluster")
		  }
		  
		  Output(:EcsClusterArn) {
		    Value(FnGetAtt('EcsCluster','Arn'))
		    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-EcsClusterArn")
		  }
		  
		  fargate_only_cluster = external_parameters.fetch(:fargate_only_cluster, false)
		  
		  unless fargate_only_cluster
		    
		    Condition(:SpotEnabled, FnEquals(Ref(:Spot), 'true'))
		    Condition(:KeyPairSet, FnNot(FnEquals(Ref(:KeyPair), '')))
		    Condition(:IsScalingEnabled, FnEquals(Ref(:EnableScaling), 'true'))
		    Condition(:IsTargetTrackingScalingEnabled, FnEquals(Ref(:EnableTargetTrackingScaling), 'true')) 
		    
		    ip_blocks = external_parameters.fetch(:ip_blocks, {})
		    security_group_rules = external_parameters.fetch(:security_group_rules, [])
		    
		    EC2_SecurityGroup(:SecurityGroupEcs) {
		      VpcId Ref(:VPCId)
		      GroupDescription FnSub("${EnvironmentName}-#{external_parameters[:component_name]}")
		      
		      if security_group_rules.any?
		        SecurityGroupIngress generate_security_group_rules(security_group_rules,ip_blocks)
		      end
		      
		      Tags ecs_tags
		    }
		
		    Output(:EcsSecurityGroup) {
		      Value(Ref('SecurityGroupEcs'))
		      Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-EcsSecurityGroup")
		    }
		  
		    IAM_Role(:Role) {
		      Path '/'
		      AssumeRolePolicyDocument service_assume_role_policy('ec2')
		      Policies iam_role_policies(external_parameters[:iam_policies])
		      Tags ecs_tags
		    }
		    
		    InstanceProfile(:InstanceProfile) {
		      Path '/'
		      Roles [Ref(:Role)]
		    }
		    
		    instance_userdata = <<~USERDATA
		    #!/bin/bash
		    iptables --insert FORWARD 1 --in-interface docker+ --destination 169.254.169.254/32 --jump DROP
		    service iptables save
		    echo ECS_CLUSTER=${EcsCluster} >> /etc/ecs/ecs.config
		    USERDATA
		    
		    ecs_agent_config = external_parameters.fetch(:ecs_agent_config, {})
		    instance_userdata += ecs_agent_config.map { |k,v| "echo #{k}=#{v} >> /etc/ecs/ecs.config" }.join('\n')
		    
		    userdata = external_parameters.fetch(:userdata, '')
		    instance_userdata += "\n#{userdata}"
		    
		    ecs_instance_tags = ecs_tags.map(&:clone)
		    ecs_instance_tags.push({ Key: 'Role', Value: 'ecs' })
		    ecs_instance_tags.push({ Key: 'Name', Value: FnSub("${EnvironmentName}-ecs-xx") })
		    
		    instance_tags = external_parameters.fetch(:instance_tags, {})
		    ecs_instance_tags.push(*instance_tags.map {|k,v| {Key: k, Value: FnSub(v)}})
		    
		    template_data = {
		        SecurityGroupIds: [ Ref(:SecurityGroupEcs) ],
		        TagSpecifications: [
		          { ResourceType: 'instance', Tags: ecs_instance_tags },
		          { ResourceType: 'volume', Tags: ecs_instance_tags }
		        ],
		        UserData: FnBase64(FnSub(instance_userdata)),
		        IamInstanceProfile: { Name: Ref(:InstanceProfile) },
		        KeyName: FnIf(:KeyPairSet, Ref(:KeyPair), Ref('AWS::NoValue')),
		        ImageId: Ref(:Ami),
		        InstanceType: Ref(:InstanceType)
		    }
		
		    spot_options = {
		      MarketType: 'spot',
		      SpotOptions: {
		        SpotInstanceType: 'one-time',
		      }
		    }
		    template_data[:InstanceMarketOptions] = FnIf(:SpotEnabled, spot_options, Ref('AWS::NoValue'))
		
		    volumes = external_parameters.fetch(:volumes, {})
		    if volumes.any?
		      template_data[:BlockDeviceMappings] = volumes
		    end
		    
		    EC2_LaunchTemplate(:LaunchTemplate) {
		      LaunchTemplateData(template_data)
		    }
		    
		    ecs_asg_tags = ecs_tags.map(&:clone)
		
		    AutoScaling_AutoScalingGroup(:AutoScaleGroup) {
		      UpdatePolicy(:AutoScalingReplacingUpdate, {
		        WillReplace: true
		      })
		      UpdatePolicy(:AutoScalingScheduledAction, {
		        IgnoreUnmodifiedGroupSizeProperties: true
		      })
		      DesiredCapacity Ref(:AsgDesired)
		      MinSize Ref(:AsgMin)
		      MaxSize Ref(:AsgMax)
		      VPCZoneIdentifiers Ref(:Subnets)
		      LaunchTemplate({
		        LaunchTemplateId: Ref(:LaunchTemplate),
		        Version: FnGetAtt(:LaunchTemplate, :LatestVersionNumber)
		      })
		      Tags ecs_asg_tags.each {|tag| tag[:PropagateAtLaunch]=false}
		    }
		    
		    Output(:AutoScalingGroupName) {
		      Value(Ref(:AutoScaleGroup))
		      Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-AutoScalingGroupName")
		    }
		        
		    IAM_Role(:DrainECSHookFunctionRole) {
		      Path '/'
		      AssumeRolePolicyDocument service_assume_role_policy('lambda')
		      Policies iam_role_policies(external_parameters[:dain_hook_iam_policies])
		      Tags ecs_tags
		    }
		    
		    Lambda_Function(:DrainECSHookFunction) {
		      Handler 'index.lambda_handler'
		      Timeout 300
		      Code({
		        ZipFile: <<~LAMBDA
		        import boto3, json, os, time
		
		        ecs = boto3.client('ecs')
		        autoscaling = boto3.client('autoscaling')
		
		        def lambda_handler(event, context):
		            print(json.dumps(event))
		            cluster = os.environ['CLUSTER']
		            snsTopicArn = event['Records'][0]['Sns']['TopicArn']
		            lifecycle_event = json.loads(event['Records'][0]['Sns']['Message'])
		            instance_id = lifecycle_event.get('EC2InstanceId')
		            if not instance_id:
		                print('Got event without EC2InstanceId: %s', json.dumps(event))
		                return
		
		            instance_arn = container_instance_arn(cluster, instance_id)
		            print('Instance %s has container instance ARN %s' % (lifecycle_event['EC2InstanceId'], instance_arn))
		
		            if not instance_arn:
		                return
		
		            while has_tasks(cluster, instance_arn):
		                time.sleep(10)
		
		            try:
		                print('Terminating instance %s' % instance_id)
		                autoscaling.complete_lifecycle_action(
		                    LifecycleActionResult='CONTINUE',
		                    **pick(lifecycle_event, 'LifecycleHookName', 'LifecycleActionToken', 'AutoScalingGroupName'))
		            except Exception as e:
		                # Lifecycle action may have already completed.
		                print(str(e))
		
		
		        def container_instance_arn(cluster, instance_id):
		            """Turn an instance ID into a container instance ARN."""
		            arns = ecs.list_container_instances(cluster=cluster, filter='ec2InstanceId==' + instance_id)['containerInstanceArns']
		            if not arns:
		                return None
		            return arns[0]
		
		
		        def has_tasks(cluster, instance_arn):
		            """Return True if the instance is running tasks for the given cluster."""
		            instances = ecs.describe_container_instances(cluster=cluster, containerInstances=[instance_arn])['containerInstances']
		            if not instances:
		                return False
		            instance = instances[0]
		
		            if instance['status'] == 'ACTIVE':
		                # Start draining, then try again later
		                set_container_instance_to_draining(cluster, instance_arn)
		                return True
		
		            tasks = instance['runningTasksCount'] + instance['pendingTasksCount']
		            print('Instance %s has %s tasks' % (instance_arn, tasks))
		
		            return tasks > 0
		
		
		        def set_container_instance_to_draining(cluster, instance_arn):
		            ecs.update_container_instances_state(
		                cluster=cluster,
		                containerInstances=[instance_arn], status='DRAINING')
		
		
		        def pick(dct, *keys):
		            """Pick a subset of a dict."""
		            return {k: v for k, v in dct.items() if k in keys}
		        LAMBDA
		      })
		      Role FnGetAtt(:DrainECSHookFunctionRole, :Arn)
		      Runtime 'python3.7'
		      Environment({
		        Variables: {
		          CLUSTER: Ref(:EcsCluster)
		        }
		      })
		      Tags ecs_tags
		    }
		    
		    Lambda_Permission(:DrainECSHookPermissions) {
		      Action 'lambda:InvokeFunction'
		      FunctionName FnGetAtt(:DrainECSHookFunction, :Arn)
		      Principal 'sns.amazonaws.com'
		      SourceArn Ref(:DrainECSHookTopic)
		    }
		    
		    SNS_Topic(:DrainECSHookTopic) {
		      Subscription([
		        {
		          Endpoint: FnGetAtt(:DrainECSHookFunction, :Arn),
		          Protocol: 'lambda'
		        }
		      ])
		      Tags ecs_tags
		    }
		        
		    IAM_Role(:DrainECSHookTopicRole) {
		      Path '/'
		      AssumeRolePolicyDocument service_assume_role_policy('autoscaling')
		      Policies iam_role_policies(external_parameters[:dain_hook_topic_iam_policies])
		      Tags ecs_tags
		    }
		    
		    AutoScaling_LifecycleHook(:DrainECSHook) {
		      AutoScalingGroupName Ref(:AutoScaleGroup)
		      LifecycleTransition 'autoscaling:EC2_INSTANCE_TERMINATING'
		      DefaultResult 'CONTINUE'
		      HeartbeatTimeout 300
		      NotificationTargetARN Ref(:DrainECSHookTopic)
		      RoleARN FnGetAtt(:DrainECSHookTopicRole, :Arn)
		    }
		
		    asg_scaling = external_parameters.fetch(:asg_scaling, {})
		    scale_up = asg_scaling.fetch('up', {})
		    scale_down = asg_scaling.fetch('down', {})
		    asg_dimensions = [{Name: 'ClusterName', Value: Ref(:EcsCluster)}]
		  
		    CloudWatch_Alarm(:ScaleUpAlarm) {
		      Condition 'IsScalingEnabled'
		      AlarmDescription FnSub(scale_up.fetch('desc', "${EnvironmentName #{component_name} scale up alarm"))
		      MetricName scale_up.fetch('metric_name', 'CPUReservation')
		      Namespace scale_up.fetch('namespace', 'AWS/ECS')
		      Statistic scale_up.fetch('statistic', 'Average')
		      Period scale_up.fetch('period', '60').to_s
		      EvaluationPeriods scale_up.fetch('evaluation_periods', '5').to_s
		      Threshold scale_up.fetch('threshold', '70').to_s
		      AlarmActions [Ref(:ScaleUpPolicy)]
		      ComparisonOperator scale_up.fetch('operator', 'GreaterThanThreshold')
		      Dimensions scale_up.fetch('dimensions', asg_dimensions)
		    }
		  
		    CloudWatch_Alarm(:ScaleDownAlarm) {
		      Condition 'IsScalingEnabled'
		      AlarmDescription FnSub(scale_down.fetch('desc', "${EnvironmentName #{component_name} scale down alarm"))
		      MetricName scale_down.fetch('metric_name', 'CPUReservation')
		      Namespace scale_down.fetch('namespace', 'AWS/ECS')
		      Statistic scale_down.fetch('statistic', 'Average')
		      Period scale_down.fetch('period', '60').to_s
		      EvaluationPeriods scale_down.fetch('evaluation_periods', '10').to_s
		      Threshold scale_down.fetch('threshold', '40').to_s
		      AlarmActions [Ref(:ScaleDownPolicy)]
		      ComparisonOperator scale_down.fetch('operator', 'LessThanThreshold')
		      Dimensions scale_down.fetch('dimensions', asg_dimensions)
		    }
		  
		    step_up_scaling = scale_up.fetch('step_adjustments', [])
		  
		    AutoScaling_ScalingPolicy(:ScaleUpPolicy) {
		      Condition 'IsScalingEnabled'
		      AdjustmentType scale_up.fetch('adjustment_type', 'ChangeInCapacity')
		      AutoScalingGroupName Ref('AutoScaleGroup')
		      if step_up_scaling.any?
		        PolicyType 'StepScaling'
		        StepAdjustments step_up_scaling
		        EstimatedInstanceWarmup scale_up.fetch('warmup', 300).to_i
		      else
		        Cooldown scale_up.fetch('cooldown', '300').to_s
		        ScalingAdjustment scale_up.fetch('adjustment', 1)
		      end
		    }
		  
		    step_down_scaling = scale_down.fetch('step_adjustments', [])
		  
		    AutoScaling_ScalingPolicy(:ScaleDownPolicy) {
		      Condition 'IsScalingEnabled'
		      AdjustmentType 'ChangeInCapacity'
		      AutoScalingGroupName Ref('AutoScaleGroup')
		      if step_down_scaling.any?
		        PolicyType 'StepScaling'
		        StepAdjustments step_down_scaling
		        EstimatedInstanceWarmup scale_up.fetch('warmup', 300).to_i
		      else
		        Cooldown scale_up.fetch('cooldown', '300').to_s
		        ScalingAdjustment scale_down.fetch('adjustment', -1)
		      end
		    }
		  
		    target_tracking = external_parameters.fetch(:target_tracking, {})
		  
		    target_tracking.each do |name,config|
		      AutoScaling_ScalingPolicy(name) {
		        Condition 'IsTargetTrackingScalingEnabled'
		        AutoScalingGroupName Ref('AutoScaleGroup')
		        PolicyType 'TargetTrackingScaling'
		        TargetTrackingConfiguration config
		        EstimatedInstanceWarmup scale_up.fetch('warmup', 60).to_i
		      }
		    end        
		    
		  end
		  
		



    # cfhighlander generated lambda functions
    

    # cfhighlander generated parameters

    Parameter('EnvironmentName') do
      Type 'String'
      Default 'dev'
      NoEcho false
    end

    Parameter('EnvironmentType') do
      Type 'String'
      Default 'development'
      NoEcho false
      AllowedValues ["development", "production"]
    end

    Parameter('VPCId') do
      Type 'AWS::EC2::VPC::Id'
      Default ''
      NoEcho false
    end

    Parameter('ContainerInsights') do
      Type 'String'
      Default 'disabled'
      NoEcho false
      AllowedValues ["enabled", "disabled"]
    end

    Parameter('AvailabilityZones') do
      Type 'String'
      Default '3'
      NoEcho false
    end



    Description 'ecs-v2 - latest'

    Output('CfTemplateUrl') {
        Value("/ecs-v2.compiled.yaml")
    }
    Output('CfTemplateVersion') {
        Value("latest")
    }
end
