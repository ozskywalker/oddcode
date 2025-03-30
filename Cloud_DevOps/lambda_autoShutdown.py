import boto3

# TODO: shift this to an environment variable?
dryRun = False

# TODO: re-code to search thru all regions
region = 'us-east-1'

# TODO: shift this to an environment variable?
ignoreTag = 'DoNotAutoShutdown'

# TODO: better error checking
def lambda_handler(event, context):
    ec2 = boto3.resource('ec2')
    ec = boto3.client('ec2')
    instances = ec2.instances.filter(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}])
    stoplist = []
    
    if dryRun:
        print '+++dryRun enabled+++'

    for instance in instances:
        print instance.id + ': found instance (type ' + instance.instance_type + ')'
        
        skipInstance = False
        if instance.tags is None:
            print instance.id + ': instance has no tags!'
        else:
            for t in instance.tags:
                if t['Key'].lower() == ignoreTag.lower():
                    if t['Value'].lower() == 'true':
                        skipInstance = True
        
        if skipInstance:
            print instance.id + ': instance is marked as ' + ignoreTag
        else:
            stoplist.append(instance.id)
    
    if dryRun:
        print '+++ec.stop_instance: dryrun trigger for instances', stoplist
    else:
        print 'sending stop request for instances', stoplist
        ec.stop_instances(InstanceIds=stoplist)
                
    print '+++end of lambda function+++'