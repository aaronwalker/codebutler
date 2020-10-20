
    load('/Users/aaronwalker/.chefdk/gem/ruby/2.5.0/gems/cfhighlander-0.12.1/lib/../cfndsl_ext/iam_helper.rb')

    load('/Users/aaronwalker/.chefdk/gem/ruby/2.5.0/gems/cfhighlander-0.12.1/lib/../cfndsl_ext/lambda_helper.rb')

CloudFormation do
  # cfhl meta: cfndsl_version=1.0.2
  component_version = external_parameters.fetch(:component_version, nil)
  component_name = external_parameters.fetch(:component_name, nil)
  template_name = external_parameters.fetch(:template_name, nil)
  template_version = external_parameters.fetch(:template_version, nil)
  template_dir = external_parameters.fetch(:template_dir, nil)
  description = external_parameters.fetch(:description, nil)

  # render subcomponents

    CloudFormation_Stack('ecs') do
        TemplateURL './ecs.compiled.yaml'

        Parameters ({
        	'EnvironmentName' => {"Ref":"EnvironmentName"},
        	'EnvironmentType' => {"Ref":"EnvironmentType"},
        	'VPCId' => {"Ref":"VPCId"},
        	'ContainerInsights' => 'disabled',
        	'AvailabilityZones' => '3',
        })
        
    end

    CloudFormation_Stack('greeterservice') do
        TemplateURL './greeter-service.compiled.yaml'

        Parameters ({
        	'EnvironmentName' => {"Ref":"EnvironmentName"},
        	'EnvironmentType' => {"Ref":"EnvironmentType"},
        	'VPCId' => {"Ref":"VPCId"},
        	'SubnetIds' => {"Ref":"SubnetIds"},
        	'EcsCluster' => {"Fn::GetAtt":["ecs","Outputs.EcsCluster"]},
        	'DesiredCount' => '1',
        	'MinimumHealthyPercent' => '100',
        	'MaximumPercent' => '200',
        	'EnableScaling' => 'false',
        	'greeterserviceTaskGreeterVersion' => {"Ref":"GreeterServiceTag"},
        })
        
    end






    # cfhighlander generated lambda functions
    

    # cfhighlander generated parameters

    Parameter('VPCId') do
      Type 'String'
      Default ''
      NoEcho false
    end

    Parameter('SubnetIds') do
      Type 'String'
      Default ''
      NoEcho false
    end

    Parameter('GreeterServiceTag') do
      Type 'String'
      Default ''
      NoEcho false
    end

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



    Description 'Greeter Service - (greeter@latest)'

    Output('CfTemplateUrl') {
        Value("/greeter.compiled.yaml")
    }
    Output('CfTemplateVersion') {
        Value("latest")
    }
end
