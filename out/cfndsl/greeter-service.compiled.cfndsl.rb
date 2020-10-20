
    load('/Users/aaronwalker/.chefdk/gem/ruby/2.5.0/gems/cfhighlander-0.12.1/lib/../cfndsl_ext/iam_helper.rb')

    load('/Users/aaronwalker/.chefdk/gem/ruby/2.5.0/gems/cfhighlander-0.12.1/lib/../cfndsl_ext/lambda_helper.rb')

    load('/Users/aaronwalker/.cfhighlander/components/lib-iam/0.1.0/ext/cfndsl/role.rb')

    load('/Users/aaronwalker/.cfhighlander/components/lib-ec2/0.1.0/ext/cfndsl/security_group.rb')

CloudFormation do
  # cfhl meta: cfndsl_version=1.0.2
  task_type = external_parameters.fetch(:task_type, nil)
  network_mode = external_parameters.fetch(:network_mode, nil)
  cpu = external_parameters.fetch(:cpu, nil)
  memory = external_parameters.fetch(:memory, nil)
  iam_policies = external_parameters.fetch(:iam_policies, nil)
  platform_version = external_parameters.fetch(:platform_version, nil)
  cpu = external_parameters.fetch(:cpu, nil)
  memory = external_parameters.fetch(:memory, nil)
  task_definition = external_parameters.fetch(:task_definition, nil)
  nested_component = external_parameters.fetch(:nested_component, nil)
  component_version = external_parameters.fetch(:component_version, nil)
  component_name = external_parameters.fetch(:component_name, nil)
  template_name = external_parameters.fetch(:template_name, nil)
  template_version = external_parameters.fetch(:template_version, nil)
  template_dir = external_parameters.fetch(:template_dir, nil)
  description = external_parameters.fetch(:description, nil)

  # render subcomponents

    CloudFormation_Stack('greeterserviceTask') do
        TemplateURL './greeterserviceTask.compiled.yaml'

        Parameters ({
        	'EnvironmentName' => {"Ref":"EnvironmentName"},
        	'EnvironmentType' => {"Ref":"EnvironmentType"},
        	'DnsDomain' => {"Ref":"DnsDomain"},
        })
        
    end



		  export = external_parameters.fetch(:export_name, external_parameters[:component_name])
		
		  task_definition = external_parameters.fetch(:task_definition, nil)
		  if task_definition.nil?
		    raise 'you must define a task_definition'
		  end
		
		  EC2_SecurityGroup(:SecurityGroup) do
		    VpcId Ref('VPCId')
		    GroupDescription "#{external_parameters[:component_name]} fargate service"
		    Metadata({
		      cfn_nag: {
		        rules_to_suppress: [
		          { id: 'F1000', reason: 'ignore egress for now' }
		        ]
		      }
		    })
		  end
		  Output(:SecurityGroup) {
		    Value(Ref(:SecurityGroup))
		    Export FnSub("${EnvironmentName}-#{export}-SecurityGroup")
		  }
		
		  ingress_rules = external_parameters.fetch(:ingress_rules, [])
		  ingress_rules.each_with_index do |ingress_rule, i|
		    EC2_SecurityGroupIngress("IngressRule#{i+1}") do
		      Description ingress_rule['desc'] if ingress_rule.has_key?('desc')
		      GroupId ingress_rule.has_key?('dest_sg') ? ingress_rule['dest_sg'] : Ref(:SecurityGroup)
		      SourceSecurityGroupId ingress_rule.has_key?('source_sg') ? ingress_rule['source_sg'] :  Ref(:SecurityGroup)
		      IpProtocol ingress_rule.has_key?('protocol') ? ingress_rule['protocol'] : 'tcp'
		      FromPort ingress_rule['from']
		      ToPort ingress_rule.has_key?('to') ? ingress_rule['to'] : ingress_rule['from']
		    end
		  end
		
		  service_loadbalancer = []
		  targetgroup = external_parameters.fetch(:targetgroup, {})
		  unless targetgroup.empty?
		
		    if targetgroup.has_key?('rules')
		
		      attributes = []
		
		      targetgroup['attributes'].each do |key,value|
		        attributes << { Key: key, Value: value }
		      end if targetgroup.has_key?('attributes')
		
		      tags = []
		      tags << { Key: "Environment", Value: Ref("EnvironmentName") }
		      tags << { Key: "EnvironmentType", Value: Ref("EnvironmentType") }
		
		      targetgroup['tags'].each do |key,value|
		        tags << { Key: key, Value: value }
		      end if targetgroup.has_key?('tags')
		
		      ElasticLoadBalancingV2_TargetGroup('TaskTargetGroup') do
		        ## Required
		        Port targetgroup['port']
		        Protocol targetgroup['protocol'].upcase
		        VpcId Ref('VPCId')
		        ## Optional
		        if targetgroup.has_key?('healthcheck')
		          HealthCheckPort targetgroup['healthcheck']['port'] if targetgroup['healthcheck'].has_key?('port')
		          HealthCheckProtocol targetgroup['healthcheck']['protocol'] if targetgroup['healthcheck'].has_key?('port')
		          HealthCheckIntervalSeconds targetgroup['healthcheck']['interval'] if targetgroup['healthcheck'].has_key?('interval')
		          HealthCheckTimeoutSeconds targetgroup['healthcheck']['timeout'] if targetgroup['healthcheck'].has_key?('timeout')
		          HealthyThresholdCount targetgroup['healthcheck']['heathy_count'] if targetgroup['healthcheck'].has_key?('heathy_count')
		          UnhealthyThresholdCount targetgroup['healthcheck']['unheathy_count'] if targetgroup['healthcheck'].has_key?('unheathy_count')
		          HealthCheckPath targetgroup['healthcheck']['path'] if targetgroup['healthcheck'].has_key?('path')
		          Matcher ({ HttpCode: targetgroup['healthcheck']['code'] }) if targetgroup['healthcheck'].has_key?('code')
		        end
		
		        TargetType targetgroup['type'] if targetgroup.has_key?('type')
		        TargetGroupAttributes attributes if attributes.any?
		
		        Tags tags if tags.any?
		      end
		
		      targetgroup['rules'].each_with_index do |rule, index|
		        listener_conditions = []
		        if rule.key?("path")
		          listener_conditions << { Field: "path-pattern", Values: [ rule["path"] ].flatten() }
		        end
		        if rule.key?("host")
		          hosts = []
		          if rule["host"].include?('!DNSDomain')
		            host_subdomain = rule["host"].gsub('!DNSDomain', '') #remove <DNSDomain>
		            hosts << FnJoin("", [ host_subdomain , Ref('DnsDomain') ])
		          elsif rule["host"].include?('.')
		            hosts << rule["host"]
		          else
		            hosts << FnJoin("", [ rule["host"], ".", Ref('DnsDomain') ])
		          end
		          listener_conditions << { Field: "host-header", Values: hosts }
		        end
		
		        if rule.key?("name")
		          rule_name = rule['name']
		        elsif rule['priority'].is_a? Integer
		          rule_name = "TargetRule#{rule['priority']}"
		        else
		          rule_name = "TargetRule#{index}"
		        end
		
		        ElasticLoadBalancingV2_ListenerRule(rule_name) do
		          Actions [{ Type: "forward", TargetGroupArn: Ref('TaskTargetGroup') }]
		          Conditions listener_conditions
		          ListenerArn Ref("Listener")
		          Priority rule['priority']
		        end
		
		      end
		
		      targetgroup_arn = Ref('TaskTargetGroup')
		
		      Output("TaskTargetGroup") {
		        Value(Ref('TaskTargetGroup'))
		        Export FnSub("${EnvironmentName}-#{export}-targetgroup")
		      }
		    else
		      targetgroup_arn = Ref('TargetGroup')
		    end
		
		
		    service_loadbalancer << {
		      ContainerName: targetgroup['container'],
		      ContainerPort: targetgroup['port'],
		      TargetGroupArn: targetgroup_arn
		    }
		
		  end
		
		  health_check_grace_period = external_parameters.fetch(:health_check_grace_period, nil)
		  unless task_definition.empty?
		
		    ECS_Service('EcsFargateService') do
		      Cluster Ref("EcsCluster")
		      DesiredCount Ref('DesiredCount')
		      DeploymentConfiguration ({
		          MinimumHealthyPercent: Ref('MinimumHealthyPercent'),
		          MaximumPercent: Ref('MaximumPercent')
		      })
		      TaskDefinition "Ref" => "Task" #Hack to work referencing child component resource
		      HealthCheckGracePeriodSeconds health_check_grace_period unless health_check_grace_period.nil?
		      LaunchType "FARGATE"
		
		      if service_loadbalancer.any?
		        LoadBalancers service_loadbalancer
		      end
		
		      NetworkConfiguration ({
		        AwsvpcConfiguration: {
		          AssignPublicIp: external_parameters[:public_ip] ? "ENABLED" : "DISABLED",
		          SecurityGroups: [ Ref(:SecurityGroup) ],
		          Subnets: Ref('SubnetIds')
		        }
		      })
		
		    end
		
		    Output('ServiceName') do
		      Value(FnGetAtt('EcsFargateService', 'Name'))
		      Export FnSub("${EnvironmentName}-#{export}-ServiceName")
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

    Parameter('SubnetIds') do
      Type 'CommaDelimitedList'
      Default ''
      NoEcho false
    end

    Parameter('EcsCluster') do
      Type 'String'
      Default ''
      NoEcho false
    end

    Parameter('DesiredCount') do
      Type 'String'
      Default '1'
      NoEcho false
    end

    Parameter('MinimumHealthyPercent') do
      Type 'String'
      Default '100'
      NoEcho false
    end

    Parameter('MaximumPercent') do
      Type 'String'
      Default '200'
      NoEcho false
    end

    Parameter('EnableScaling') do
      Type 'String'
      Default 'false'
      NoEcho false
      AllowedValues ["true", "false"]
    end

    Parameter('greeterserviceTaskGreeterVersion') do
      Type 'String'
      Default '{"Ref"=>"GreeterServiceTag"}'
      NoEcho false
    end



    Description 'greeter-service - vlatest (fargate-v2@latest)'

    Output('CfTemplateUrl') {
        Value("/fargate-v2.compiled.yaml")
    }
    Output('CfTemplateVersion') {
        Value("latest")
    }
end
