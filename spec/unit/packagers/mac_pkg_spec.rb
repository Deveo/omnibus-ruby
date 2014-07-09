require 'stringio'
require 'spec_helper'

module Omnibus
  describe Packager::MacPkg do
    before do
      Config.package_dir('/home/someuser/omnibus-myproject/pkg')
      Config.package_tmp('/var/cache/omnibus/pkg-tmp')
    end

    let(:project_name) { 'myproject' }

    let(:mac_pkg_identifier) { 'com.mycorp.myproject' }

    let(:omnibus_root) { '/omnibus/project/root' }

    let(:scripts_path) { "#{omnibus_root}/scripts" }

    let(:files_path) { "#{omnibus_root}/files" }

    let(:expected_distribution_content) do
      <<-EOH
<?xml version="1.0" standalone="no"?>
<installer-gui-script minSpecVersion="1">
    <title>Myproject</title>
    <background file="background.png" alignment="bottomleft" mime-type="image/png"/>
    <welcome file="welcome.html" mime-type="text/html"/>
    <license file="license.html" mime-type="text/html"/>

    <!-- Generated by productbuild - - synthesize -->
    <pkg-ref id="com.mycorp.myproject"/>
    <options customize="never" require-scripts="false"/>
    <choices-outline>
        <line choice="default">
            <line choice="com.mycorp.myproject"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.mycorp.myproject" visible="false">
        <pkg-ref id="com.mycorp.myproject"/>
    </choice>
    <pkg-ref id="com.mycorp.myproject" version="23.4.2" onConclusion="none">myproject-core.pkg</pkg-ref>
</installer-gui-script>
  EOH
    end

    let(:expected_distribution_path) { '/var/cache/omnibus/pkg-tmp/mac_pkg/Distribution' }

    let(:project) do
      double(Project,
        name: project_name,
        build_version: '23.4.2',
        build_iteration: 4,
        maintainer: "Joe's Software",
        install_dir: '/opt/myproject',
        files_path: files_path,
        package_scripts_path: scripts_path,
        mac_pkg_identifier: mac_pkg_identifier,
        friendly_name: 'Myproject'
      )
    end

    let(:packager) { Packager::MacPkg.new(project) }

    it 'names the component package PROJECT_NAME-core.pkg' do
      expect(packager.component_pkg).to eq('myproject-core.pkg')
    end

    it 'names the product package PROJECT_NAME.pkg' do
      expect(packager.package_name).to eq('myproject-23.4.2-4.pkg')
    end

    it 'runs pkgbuild' do
      expect(packager).to receive(:execute).with <<-EOH.gsub(/^ {8}/, '')
        pkgbuild \\
          --identifier "com.mycorp.myproject" \\
          --version "23.4.2" \\
          --scripts "/omnibus/project/root/scripts" \\
          --root "/opt/myproject" \\
          --install-location "/opt/myproject" \\
          "myproject-core.pkg"
      EOH
      packager.build_component_pkg
    end

    it 'generates a Distribution file describing the product package content' do
      file = StringIO.new
      File.stub(:open).with(any_args).and_yield(file)

      expect(file).to receive(:puts).with(expected_distribution_content)
      packager.generate_distribution
    end

    describe 'generating the distribution file' do
      let(:distribution_file) { StringIO.new }

      before do
        expect(File).to receive(:open)
          .with(expected_distribution_path, 'w', 0600)
          .and_yield(distribution_file)
      end

      it 'writes the distribution file to the staging directory' do
        packager.generate_distribution
        expect(distribution_file.string).to eq(expected_distribution_content)
      end
    end

    describe '#build_product_pkg' do
      context 'when pkg signing is disabled' do
        it 'generates the distribution and runs productbuild' do
          expect(packager).to receive(:execute).with <<-EOH.gsub(/^ {12}/, '')
            productbuild \\
              --distribution "/var/cache/omnibus/pkg-tmp/mac_pkg/Distribution" \\
              --resources "/var/cache/omnibus/pkg-tmp/mac_pkg/Resources" \\
              "/home/someuser/omnibus-myproject/pkg/myproject-23.4.2-4.pkg"
          EOH

          packager.build_product_pkg
        end
      end

      context 'when pkg signing is enabled' do
        before do
          Config.sign_pkg(true)
          Config.signing_identity('My Special Identity')
        end

        it 'includes the signing parameters in the product build command' do
          expect(packager).to receive(:execute).with  <<-EOH.gsub(/^ {12}/, '')
            productbuild \\
              --distribution "/var/cache/omnibus/pkg-tmp/mac_pkg/Distribution" \\
              --resources "/var/cache/omnibus/pkg-tmp/mac_pkg/Resources" \\
              --sign "My Special Identity" \\
              "/home/someuser/omnibus-myproject/pkg/myproject-23.4.2-4.pkg"
            EOH
          packager.build_product_pkg
        end
      end

      context "when the mac_pkg_identifier isn't specified by the project" do
        let(:mac_pkg_identifier) { nil }
        let(:project_name) { 'My $Project' }

        it 'uses com.example.PROJECT_NAME as the identifier' do
          expect(packager.identifier).to eq('test.joessoftware.pkg.myproject')
        end
      end
    end
  end
end
