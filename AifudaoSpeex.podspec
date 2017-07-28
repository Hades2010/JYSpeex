
Pod::Spec.new do |s|
    s.name             = 'JYSpeex'
    s.version          = '0.0.1'
    s.summary          = 'JYSpeex'
    s.description      = <<-DESC
                        Speex
                       DESC
    s.homepage         = 'git@github.com:Hades2010/JYSpeex.git'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'woz' => 'woz' }
    s.source           = { :git => 'git@github.com:Hades2010/JYSpeex.git'}
    s.ios.deployment_target = '7.0'
    s.frameworks = 'UIKit' , 'Foundation'
    s.source_files = 'AFDSpeex/Speexo/**/*'
#    s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SRCROOT)/**' }
    s.pod_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '${SRCROOT}/**' }
    s.user_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SRCROOT)/**' }
    s.resource = ''
    s.requires_arc = true
end
