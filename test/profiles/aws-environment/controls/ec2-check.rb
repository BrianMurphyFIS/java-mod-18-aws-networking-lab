title 'EC2 Environment checks'


control 'EC2 AMI' do
  impact 'critical'
  title 'EC2 AMI'
  desc 'Check if Docker Ubuntu AMI has been created.'
  desc 'step', '4'

  describe.one do
    describe "image" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_amis(name: 'docker-ami').image_ids.each do |image|
      describe aws_ami(image_id: image) do
        it { should exist }
      end
    end
  end
end


control 'Lab VPC' do
  impact 'critical'
  title 'Lab VPC'
  desc 'Check if Lab VPC has been created.'
  desc 'step', '1'

  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  describe vpcs do
    it { should exist }
  end

  describe.one do
    describe "vpc" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    vpcs.vpc_ids.each do |vpc|
      describe aws_vpc(vpc_id: vpc) do
        it { should exist }
        it { should be_available }
        its('cidr_block') { should cmp '10.0.0.0/16' }
        its('name') { should eq "lab-vpc"}
      end
    end
  end
end


control 'Lab Public1 Subnet' do
  impact 'critical'
  title 'Lab Public1 Subnet'
  desc 'Check if Lab Subnet has been created.'
  desc 'step', '2'

  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  vpc_id = vpcs.vpc_ids[0]

  describe.one do
    describe "subnet" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_subnets.where(vpc_id: vpc_id).subnet_ids.each do |subnet|
      describe aws_subnet(subnet_id: subnet) do
        it { should exist }
        its('availability_zone') { should eq 'us-east-1a' }
        its('cidr_block') { should eq '10.0.0.0/20' }
        its('name') { should eq 'lab-subnet-public1-us-east-1a' }
      end
    end
  end

end


control 'Lab Public2 Subnet' do
  impact 'critical'
  title 'Lab Public2 Subnet'
  desc 'Check if Lab Subnet has been created.'
  desc 'step', '2'

  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  vpc_id = vpcs.vpc_ids[0]

  describe.one do
    describe "subnet" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_subnets.where(vpc_id: vpc_id).subnet_ids.each do |subnet|
      describe aws_subnet(subnet_id: subnet) do
        it { should exist }
        its('availability_zone') { should eq 'us-east-1b' }
        its('cidr_block') { should eq '10.0.16.0/20' }
        its('name') { should eq 'lab-subnet-public2-us-east-1b' }
      end
    end
  end

end


control 'Lab Private1 Subnet' do
  impact 'critical'
  title 'Lab Private1 Subnet'
  desc 'Check if Lab Subnet has been created.'
  desc 'step', '2'

  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  vpc_id = vpcs.vpc_ids[0]

  describe.one do
    describe "subnet" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_subnets.where(vpc_id: vpc_id).subnet_ids.each do |subnet|
      describe aws_subnet(subnet_id: subnet) do
        it { should exist }
        its('availability_zone') { should eq 'us-east-1a' }
        its('cidr_block') { should eq '10.0.128.0/20' }
        its('name') { should eq 'lab-subnet-private1-us-east-1a' }
      end
    end
  end

end


control 'Lab Private2 Subnet' do
  impact 'critical'
  title 'Lab Private2 Subnet'
  desc 'Check if Lab Subnet has been created.'
  desc 'step', '2'

  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  vpc_id = vpcs.vpc_ids[0]

  describe.one do
    describe "subnet" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_subnets.where(vpc_id: vpc_id).subnet_ids.each do |subnet|
      describe aws_subnet(subnet_id: subnet) do
        it { should exist }
        its('availability_zone') { should eq 'us-east-1b' }
        its('cidr_block') { should eq '10.0.144.0/20' }
        its('name') { should eq 'lab-subnet-private2-us-east-1b' }
      end
    end
  end

end


control 'Lab Internet Gateway' do
  impact 'critical'
  title 'Lab Internet Gateway'
  desc 'Check if Lab Internet Gateway has been created.'
  desc 'step', '3'

  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  vpc_id = vpcs.vpc_ids[0]

  describe aws_internet_gateway(name: 'lab-igw') do
    it { should exist }
    it { should be_attached }
    its('name') { should eq 'lab-igw' }
    its('vpc_id') { should eq vpc_id }
  end

end


control 'Lab NAT Gateway' do
  impact 'critical'
  title 'Lab NAT Gateway'
  desc 'Check if Lab NAT Gateway has been created.'
  desc 'step', '10'

  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  vpc_id = vpcs.vpc_ids[0]

  subnet = aws_subnets.where(vpc_id: vpc_id).where{ cidr_block.include?('10.0.0.0/20')}.subnet_ids[0]

  describe aws_nat_gateway(name: 'nat-lab') do
    it { should exist }
    its('state') { should eq 'available' }
    its('name') { should eq 'nat-lab' }
    its('vpc_id') { should eq vpc_id }
    its('subnet_id') { should eq subnet }
  end

end


control 'Lab Public Route' do
  impact 'critical'
  title 'Lab Public Route'
  desc 'Check if Lab Route has been created.'
  desc 'step', '11'

  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  vpc_id = vpcs.vpc_ids[0]

  subnet1 = aws_subnets.where(vpc_id: vpc_id).where{ cidr_block.include?('10.0.0.0/20')}.subnet_ids[0]
  subnet2 = aws_subnets.where(vpc_id: vpc_id).where{ cidr_block.include?('10.0.16.0/20')}.subnet_ids[0]

  gateway_id = aws_internet_gateway(name: 'lab-igw').id

  describe.one do
    describe "route" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_route_tables.where{ vpc_id.include?(vpc_id) }.route_table_ids.each do |route|
      route_table = aws_route_table(route_table_id: route)
      route_table.routes.sort_by!{|item| item.item[:destination_cidr_block].to_s}
      describe route_table do
        it { should exist }
        its('associated_subnet_ids') { should include subnet1 }
        its('associated_subnet_ids') { should include subnet2 }
        its('name') { should eq 'lab-rtb-public' }
        its('routes.first.state') { should eq 'active' }
        its('routes.first.destination_cidr_block') { should eq '0.0.0.0/0' }
        its('routes.first.gateway_id') { should eq gateway_id }
        its('routes.last.state') { should eq 'active' }
        its('routes.last.destination_cidr_block') { should eq '10.0.0.0/16' }
        its('routes.last.gateway_id') { should eq 'local' }
      end
    end
  end

end


control 'Lab Private Route' do
  impact 'critical'
  title 'Lab Private Route'
  desc 'Check if Lab Route has been created.'
  desc 'step', '11'

  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  vpc_id = vpcs.vpc_ids[0]

  subnet1 = aws_subnets.where(vpc_id: vpc_id).where{ cidr_block.include?('10.0.128.0/20')}.subnet_ids[0]

  nat_id = aws_nat_gateway(name: 'nat-lab').id

  describe.one do
    describe "route" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_route_tables.where{ vpc_id.include?(vpc_id) }.route_table_ids.each do |route|
      route_table = aws_route_table(route_table_id: route)
      route_table.routes.sort_by!{|item| item.item[:destination_cidr_block].to_s}
      describe route_table do
        it { should exist }
        its('associated_subnet_ids') { should include subnet1 }
        its('name') { should eq 'lab-rtb-private1-us-east-1a' }
        its('routes.rotate.first.state') { should eq 'active' }
        its('routes.rotate.first.destination_cidr_block') { should eq '0.0.0.0/0' }
        its('routes.rotate.first.nat_gateway_id') { should eq nat_id }
        its('routes.last.state') { should eq 'active' }
        its('routes.last.destination_cidr_block') { should eq '10.0.0.0/16' }
        its('routes.last.gateway_id') { should eq 'local' }
      end
    end
  end

end


control 'Lab Public Network ACLs' do
  impact 'critical'
  title 'Lab Public Network ACLs'
  desc 'Check if Lab Network ACLs have been created.'
  desc 'step', '12'

  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  vpc_id = vpcs.vpc_ids[0]

  subnet1 = aws_subnets.where(vpc_id: vpc_id).where{ cidr_block.include?('10.0.0.0/20')}.subnet_ids[0]
  subnet2 = aws_subnets.where(vpc_id: vpc_id).where{ cidr_block.include?('10.0.16.0/20')}.subnet_ids[0]

  describe.one do
    describe "acl" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_network_acls.where{ vpc_id.include?(vpc_id) }.network_acl_ids.each do |acl|
      describe aws_network_acl(network_acl_id: acl) do
        it { should exist }
        it { should have_associations(subnet_id: subnet1) }
        it { should have_associations(subnet_id: subnet2) }
        it { should have_ingress(cidr_block: '0.0.0.0/0', rule_action: 'allow') }
        it { should have_egress(cidr_block: '0.0.0.0/0', rule_action: 'allow') }
        its('name') { should eq 'lab-public' }
      end
    end
  end

end


control 'Lab Private Network ACLs' do
  impact 'critical'
  title 'Lab Private Network ACLs'
  desc 'Check if Lab Network ACLs have been created.'
  desc 'step', '12'

  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  vpc_id = vpcs.vpc_ids[0]

  subnet1 = aws_subnets.where(vpc_id: vpc_id).where{ cidr_block.include?('10.0.128.0/20')}.subnet_ids[0]

  describe.one do
    describe "acl" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_network_acls.where{ vpc_id.include?(vpc_id) }.network_acl_ids.each do |acl|
      describe aws_network_acl(network_acl_id: acl) do
        it { should exist }
        it { should have_associations(subnet_id: subnet1) }
        it { should have_ingress(cidr_block: '10.0.0.0/20', rule_action: 'allow') }
        it { should have_ingress(cidr_block: '10.0.16.0/20', rule_action: 'allow') }
        it { should have_ingress(cidr_block: '0.0.0.0/0', rule_action: 'allow') }
        its('ingress_rule_number_300.cidr_block') { should eq '0.0.0.0/0' }
        its('ingress_rule_number_300.protocol') { should eq '6' }
        its('ingress_rule_number_300.rule_number') { should eq 300 }
        its('ingress_rule_number_300.port_range.from') { should eq 32768 }
        its('ingress_rule_number_300.port_range.to') { should eq 60999 }
        it { should have_egress(cidr_block: '10.0.0.0/20', rule_action: 'allow') }
        it { should have_egress(cidr_block: '10.0.16.0/20', rule_action: 'allow') }
        it { should have_egress(cidr_block: '0.0.0.0/0', rule_action: 'allow') }
        its('egress_rule_number_300.cidr_block') { should eq '0.0.0.0/0' }
        its('egress_rule_number_300.protocol') { should eq '6' }
        its('egress_rule_number_300.rule_number') { should eq 300 }
        its('egress_rule_number_300.port_range.from') { should eq 80 }
        its('egress_rule_number_300.port_range.to') { should eq 80 }
        it { should have_egress(cidr_block: '0.0.0.0/0', rule_action: 'allow') }
        its('egress_rule_number_400.cidr_block') { should eq '0.0.0.0/0' }
        its('egress_rule_number_400.protocol') { should eq '6' }
        its('egress_rule_number_400.rule_number') { should eq 400 }
        its('egress_rule_number_400.port_range.from') { should eq 443 }
        its('egress_rule_number_400.port_range.to') { should eq 443 }
        its('name') { should eq 'lab-private' }
      end
    end
  end

end


control 'ELB' do
  impact 'critical'
  title 'ELB'
  desc 'Check if ELB has been created'
  desc 'step', '14'
  
  vpcs = aws_vpcs.where { cidr_block.start_with?('10.0.0.0/16') }
  vpc_id = vpcs.vpc_ids[0]

  subnet1 = aws_subnets.where(vpc_id: vpc_id).where{ cidr_block.include?('10.0.0.0/20')}.subnet_ids[0]
  subnet2 = aws_subnets.where(vpc_id: vpc_id).where{ cidr_block.include?('10.0.16.0/20')}.subnet_ids[0]

  alb_arn = aws_albs.where(load_balancer_name: 'lab-lb').load_balancer_arns[0]
  describe aws_alb(load_balancer_arn: alb_arn)  do
    it { should exist }
    its('vpc_id') { should eq vpc_id }
    its('state.code') { should eq 'active' }
    its('load_balancer_name') { should eq 'lab-lb' }
    its('subnets') { should include subnet1 }
    its('subnets') { should include subnet2 }
    its('protocols') { should include 'TCP' }
    its('external_ports') { should include 80 }
    its('listeners.first.default_actions.first.target_group_arn') { should match /lab-lb-group/ }
  end

  target_group_arn = aws_alb(load_balancer_arn: alb_arn).listeners.first.default_actions.first.target_group_arn
  describe aws_elasticloadbalancingv2_target_group(target_group_arn: target_group_arn) do
    it { should exist }
    its('target_group_name') { should eq 'lab-lb-group' }
    its('vpc_id') { should eq vpc_id }
    its('protocol') { should eq 'TCP' }
    its('port') { should eq 80 }
    its('health_check_protocol') { should eq 'TCP' }
  end

  # The AWS InSpec resource pack doesn't currently support the "describe_target_health" API call to validate
  # LB Target Group backend Target Health status
  #
  # You can validate manually that "application-server-1", "application-server-2", and two unnamed instances(from auto-scaling)
  # are showing as "healthy" and configured for port 80.

end


control 'EC2 Auto Scaling' do
  impact 'critical'
  title 'EC2 Auto Scaling'
  desc 'Check if Auto Scaling Group is configured.'
  desc 'step', '15'

  describe aws_auto_scaling_group(auto_scaling_group_name: 'lab-scaling-group') do
    it { should exist }
    its('min_size') { should be 1 }
    its('max_size') { should be 2 }
    its('desired_capacity') { should be 2 }
  end

  describe aws_ec2_launch_template(launch_template_name: 'lab-template') do
    it { should exist }
  end

  autoscale_instances = aws_ec2_instances.where{ tags.value?('lab-scaling-group') }
  # Get full properties listing for instances
  autoscale_instances_full = Array.new(autoscale_instances.count) { |instance| aws_ec2_instance(instance_id: autoscale_instances.instance_ids[instance]) }
  describe "AWS Auto Scaling Group running-instances" do
    subject { autoscale_instances_full.select{ |instance| instance.state == 'running' } }
    its('count') { should eq 2 }
  end

end


control 'EC2 Application Instance' do
  impact 'critical'
  title 'EC2 Application Instance'
  desc 'Check if EC2 Application Instance exists and is running.'
  desc 'step', '5'

  describe.one do
    describe "instance" do
      # purposely failing test to work around describe.one bug
      it { should eq "running" }
    end
    aws_ec2_instances.where(name: 'application-server-1').instance_ids.each do |instance|
      describe aws_ec2_instance(instance_id: instance) do
        its('name') { should eq 'application-server-1' }
        its('instance_type') { should eq 't2.micro' }
        its('key_name') { should eq 'flatironschool-ec2-key' }
        it { should exist }
        it { should be_running }
      end
    end
  end

  describe.one do
    describe "image" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_ec2_instances.where(name: 'application-server-1').instance_ids.each do |instance|
      image_id = aws_ec2_instance(instance_id: instance).image_id
      describe aws_ami(image_id: image_id) do
        its('name') { should eq 'docker-ami' }
      end
    end
  end
end


control 'EC2 Application Instance 2' do
  impact 'critical'
  title 'EC2 Application Instance 2'
  desc 'Check if EC2 Application Instance 2 exists and is running.'
  desc 'step', '6'

  describe.one do
    describe "instance" do
      # purposely failing test to work around describe.one bug
      it { should eq "running" }
    end
    aws_ec2_instances.where(name: 'application-server-2').instance_ids.each do |instance|
      describe aws_ec2_instance(instance_id: instance) do
        its('name') { should eq 'application-server-2' }
        its('instance_type') { should eq 't2.micro' }
        its('key_name') { should eq 'flatironschool-ec2-key' }
        it { should exist }
        it { should be_running }
      end
    end
  end

  describe.one do
    describe "image" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_ec2_instances.where(name: 'application-server-2').instance_ids.each do |instance|
      image_id = aws_ec2_instance(instance_id: instance).image_id
      describe aws_ami(image_id: image_id) do
        its('name') { should eq 'docker-ami' }
      end
    end
  end
end


control 'EC2 Application Security Groups' do
  impact 'critical'
  title 'EC2 Application Security Groups'
  desc 'Check if EC2 Application instance has the correct security rules applied.'
  desc 'step', '5'

  describe.one do
    describe "rule" do
      # purposely failing test to work around describe.one bug
      it { should eq "exists" }
    end
    aws_ec2_instances.where(name: 'application-server-1').instance_ids.each do |instance|
      security_group_id = aws_ec2_instance(instance_id: instance).security_groups[0][:id]
      describe aws_security_group(group_id: security_group_id) do
        it { should exist }
        it { should allow_in(port: 22) }
        it { should allow_in(ipv4_range: '0.0.0.0/0', port: 80) }
        it { should allow_in(ipv4_range: '0.0.0.0/0', port: 443) }
      end
    end
  end
end


control 'EC2 Application 2 Security Groups' do
  impact 'critical'
  title 'EC2 Application 2 Security Groups'
  desc 'Check if EC2 Application instance 2 has the correct security rules applied.'
  desc 'step', '6'

  describe.one do
    describe "rule" do
      # purposely failing test to work around describe.one bug
      it { should eq "exists" }
    end
    aws_ec2_instances.where(name: 'application-server-2').instance_ids.each do |instance|
      security_group_id = aws_ec2_instance(instance_id: instance).security_groups[0][:id]
      describe aws_security_group(group_id: security_group_id) do
        it { should exist }
        it { should allow_in(port: 22) }
        it { should allow_in(ipv4_range: '0.0.0.0/0', port: 80) }
        it { should allow_in(ipv4_range: '0.0.0.0/0', port: 443) }
      end
    end
  end
end


control 'EC2 Database Instance' do
  impact 'critical'
  title 'EC2 Database Instance'
  desc 'Check if EC2 Database instance exists and is running.'
  desc 'step', '7'

  describe.one do
    describe "instance" do
      # purposely failing test to work around describe.one bug
      it { should eq "running" }
    end
    aws_ec2_instances.where(name: 'database-server-1').instance_ids.each do |instance|
      describe aws_ec2_instance(instance_id: instance) do
        its('name') { should eq 'database-server-1' }
        its('instance_type') { should eq 't2.micro' }
        its('key_name') { should eq 'flatironschool-ec2-key' }
        it { should exist }
        it { should be_running }
      end
    end
  end

  describe.one do
    describe "image" do
      # purposely failing test to work around describe.one bug
      it { should eq "exist" }
    end
    aws_ec2_instances.where(name: 'database-server-1').instance_ids.each do |instance|
      image_id = aws_ec2_instance(instance_id: instance).image_id
      describe aws_ami(image_id: image_id) do
        its('name') { should eq 'docker-ami' }
      end
    end
  end
end


control 'EC2 Database Security Groups' do
  impact 'critical'
  title 'EC2 Database Security Groups'
  desc 'Check if EC2 Database instance has the correct security rules applied.'
  desc 'step', '13'

  describe.one do
    describe "rule" do
      # purposely failing test to work around describe.one bug
      it { should eq "exists" }
    end
    aws_ec2_instances.where(name: 'database-server-1').instance_ids.each do |instance|
      security_group_id = aws_ec2_instance(instance_id: instance).security_groups[0][:id]
      describe aws_security_group(group_id: security_group_id) do
        it { should exist }
        it { should allow_in(port: 22, ipv4_range: '10.0.0.0/16') }
        it { should allow_in(port: 6379, ipv4_range: '10.0.0.0/16') }
      end
    end
  end
end
