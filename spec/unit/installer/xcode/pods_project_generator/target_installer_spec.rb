require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        describe TargetInstaller do
          before do
            @podfile = Podfile.new do
              platform :ios
              project 'SampleProject/SampleProject'
              target 'SampleProject'
            end
            @target_definition = @podfile.target_definitions['SampleProject']
            @project = Project.new(config.sandbox.project_path)

            config.sandbox.project = @project
            path_list = Sandbox::PathList.new(fixture('banana-lib'))
            @spec = fixture_spec('banana-lib/BananaLib.podspec')
            file_accessor = Sandbox::FileAccessor.new(path_list, @spec.consumer(:ios))
            @project.add_pod_group('BananaLib', fixture('banana-lib'))
            group = @project.group_for_spec('BananaLib')
            file_accessor.source_files.each do |file|
              @project.add_file_reference(file, group)
            end

            user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }
            archs = ['$(ARCHS_STANDARD_64_BIT)']
            @pod_target = PodTarget.new(config.sandbox, false, user_build_configurations, archs, [@spec], [@target_definition], Platform.ios, [file_accessor])

            @installer = TargetInstaller.new(config.sandbox, @pod_target)
          end

          it 'adds the architectures to the custom build configurations of the user target' do
            @installer.send(:add_target)
            @installer.send(:native_target).resolved_build_setting('ARCHS').should == {
              'Release' => ['$(ARCHS_STANDARD_64_BIT)'],
              'Debug' => ['$(ARCHS_STANDARD_64_BIT)'],
              'AppStore' => ['$(ARCHS_STANDARD_64_BIT)'],
              'Test' => ['$(ARCHS_STANDARD_64_BIT)'],
            }
          end

          it 'always clears the OTHER_LDFLAGS and OTHER_LIBTOOLFLAGS, because these lib targets do not ever need any' do
            @installer.send(:add_target)
            @installer.send(:native_target).resolved_build_setting('OTHER_LDFLAGS').values.uniq.should == ['']
            @installer.send(:native_target).resolved_build_setting('OTHER_LIBTOOLFLAGS').values.uniq.should == ['']
          end

          it 'adds Swift-specific build settings to the build settings' do
            @pod_target.stubs(:requires_frameworks?).returns(true)
            @pod_target.stubs(:uses_swift?).returns(true)
            @installer.send(:add_target)
            @installer.send(:native_target).resolved_build_setting('SWIFT_OPTIMIZATION_LEVEL').should == {
              'Release' => '-Owholemodule',
              'Debug' => '-Onone',
              'Test' => nil,
              'AppStore' => nil,
            }
          end

          it 'verify static framework is building a static library' do
            @pod_target.stubs(:requires_frameworks?).returns(true)
            @pod_target.stubs(:static_framework?).returns(true)
            @installer.send(:add_target)
            @installer.send(:native_target).resolved_build_setting('MACH_O_TYPE').should == {
              'Release' => 'staticlib',
              'Debug' => 'staticlib',
              'Test' => 'staticlib',
              'AppStore' => 'staticlib',
            }
          end
        end
      end
    end
  end
end
