title "AWS VM Inventory"


control 'AWS VM Inventory' do
  impact 'critical'
  title 'AWS VM Inventory'
  desc 'Return AWS running EC2 instances. The ouput will be parsed to trigger Inspec jobs on each if they exist.'
  desc 'step', '0'

  aws_ec2_instances.instance_ids.each do |instance|
    if aws_ec2_instance(instance_id: instance).state == 'running'
      describe aws_ec2_instance(instance_id: instance) do
        it { should be_running }
        its('name') { should eq 'mock' }
        its('public_ip_address') { should eq 'mock' }
        its('private_ip_address') { should eq 'mock' }
      end
    end
  end
end
