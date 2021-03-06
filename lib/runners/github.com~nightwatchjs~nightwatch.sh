#!/usr/bin/env bash.origin.script

# TODO: Relocate into plugin.
echo "TEST_MATCH_IGNORE>>>"

# TODO: Ensure exiting version is recent
if ! BO_has geckodriver; then
    echo "Installing geckodriver ..."
    brew install geckodriver
fi
# TODO: Ensure exiting version is recent
if ! BO_has chromedriver; then
    echo "Installing chromedriver ..."
    brew cask install chromedriver
fi
if [[ "$(java --version)" != "openjdk"* ]]; then
    echo "Installing java ..."
    brew cask install java
fi
# TODO: Ensure exiting version is recent
if ! BO_has selenium-server; then
    echo "Installing selenium-server-standalone ..."
    brew install selenium-server-standalone
fi
# TODO: Ensure exiting version is recent
if ! which nightwatch; then
    npm install -g nightwatch
fi
echo "<<<TEST_MATCH_IGNORE"


echo ">>>TEST_IGNORE_LINE:assertions passed\.<<<"
echo ">>>TEST_IGNORE_LINE:Connected to <<<"
echo ">>>TEST_IGNORE_LINE:Using: <<<"


function PRIVATE_ensureSeleniumServerRunning {
    local status=$(curl --write-out %{http_code} --silent --output /dev/null "http://localhost:4444")
    if [ "$status" == "000" ]; then
        BO_log "$VERBOSE" "Starting selenium server ..."
        # TODO: Direct output to logfile
        selenium-server &
        sleep 2
    fi
}



function EXPORTS_run {

    testRootFile="$1"

    workingDir="$(pwd)"
    testRelpath="$(BO_relative "$workingDir" "$testRootFile")"

    [ -z "$BO_VERBOSE" ] || echo "[bash.origin.test][runners/github.com~nightwatchjs~nightwatch] testRelpath: $testRelpath"


    PRIVATE_ensureSeleniumServerRunning


    local rtBaseDir="$(pwd)/.rt/bash.origin.test"

    BO_ensure_dir "$rtBaseDir"

    local configPath="${rtBaseDir}/nightwatch.json"
    local downloadsPath="${rtBaseDir}/downloads"

    if [ ! -e "${downloadsPath}" ]; then
        mkdir -p "${downloadsPath}"
    fi

    [ -z "$BO_VERBOSE" ] || echo "[bash.origin.test][runners/github.com~nightwatchjs~nightwatch] declare config"
    
    echo {
        "src_folders" : [],
        "output_folder" : "${rtBaseDir}/reports",
        "custom_commands_path" : "",
        "custom_assertions_path" : "",
        "page_objects_path" : "",
        "globals_path" : "",
        "selenium" : {
            "start_process" : false,
            "server_path" : "",
            "log_path" : "",
            "port" : 4444,
            "cli_args" : {
                "webdriver.chrome.driver" : "",
                "webdriver.gecko.driver" : ""
            }
        },
        "test_settings" : {
            "default" : {
                "launch_url" : "http://localhost",
                "selenium_port"  : 4444,
                "selenium_host"  : "localhost",
                "silent": true,
                "screenshots" : {
                    "enabled" : false,
                    "path" : ""
                },
                "desiredCapabilities": {
                    "browserName": "firefox",
                    "marionette": true
                }
            },
            "chrome" : {
                "desiredCapabilities": {
                    "browserName": "chrome",
                    "chromeOptions" : {
                        "w3c": false,
                        "prefs" : { 
                            "download": {
                                "default_directory": "${downloadsPath}",
                                "prompt_for_download": false
                            },
                            "profile": {
                                "default_content_setting_values" : {
                                    "automatic_downloads": 1
                                }
                            }
                        }
                    }
                }
            }
        }
    } > "${configPath}"

    [ -z "$BO_VERBOSE" ] || echo "[bash.origin.test][runners/github.com~nightwatchjs~nightwatch] update config"

    local environments=$(BO_run_silent_node --eval '
        const PATH = require("path");
        const FS = require("fs");

        var runnerConfigPath = process.argv[1];
        var testPath = PATH.resolve(process.cwd(), process.argv[2]);

        var testCode = FS.readFileSync(testPath, "utf8").replace(/\n/g, "\\n");
        var testConfig = testCode.match(/\/\*\\nmodule\.config =(.+?)\\n\*\//);

        var runnerConfig = JSON.parse(FS.readFileSync(runnerConfigPath));

        if (testConfig) {
            testConfig = testConfig[1].replace(/\\n/g, "\n");
            try {
                testConfig = JSON.parse(testConfig);
            } catch (err) {
                console.error("Error parsing testConfig from file: " + testPath);
                throw err;
            }

            if (
                testConfig.browsers &&
                testConfig.browsers.length > 0
            ) {
                if (testConfig.browsers.indexOf("chrome") === -1) {
                    delete runnerConfig.test_settings.chrome;
                } else
                if (testConfig.browsers.indexOf("firefox") === -1) {
                    runnerConfig.test_settings.default.desiredCapabilities = runnerConfig.test_settings.chrome.desiredCapabilities;
                    delete runnerConfig.test_settings.chrome;
                }
            }

            if (testConfig.test_runner) {
                runnerConfig.test_runner = testConfig.test_runner;
            }

            FS.writeFileSync(runnerConfigPath, JSON.stringify(runnerConfig, null, 4), "utf8");
        }

        process.stdout.write(Object.keys(runnerConfig.test_settings).join(","));
    ' "${configPath}" "${testRelpath}")

    [ -z "$BO_VERBOSE" ] || echo "[bash.origin.test][runners/github.com~nightwatchjs~nightwatch] run tests"

    function testEnv {

        # TODO: Get dynamic port.
        export PORT=8080

#        if [ -e "$__DIRNAME__/../../../github.com~bash-origin~bash.origin.express" ]; then
#            rm -Rf "$__DIRNAME__/.rt/it.pinf.org.npmjs/node_modules/bash.origin.express" || true
#            ln -s "../../../../../../github.com~bash-origin~bash.origin.express" "$__DIRNAME__/.rt/it.pinf.org.npmjs/node_modules/bash.origin.express"
#        fi

        echo ">>>TEST_IGNORE_LINE:Test .+<<<"
        echo ">>>TEST_IGNORE_LINE:Test: .+ms<<<"

        pushd "$(dirname "$testRelpath")" > /dev/null

            if [[ $BO_TEST_FLAG_INSPECT == 1 ]]; then

                echo "Running NodeJS with '--inspect-brk' which launches an interactive debugger ..."

                #BO_VERSION_NVM_NODE=7
                # TODO: Relocate this into a helper.
                node --eval '
                    const BO_LIB = require("bash.origin.lib").forPackage(__dirname);
                    const SPAWN = require("child_process").spawn;
                    const EXEC = require("child_process").exec;
                    const URL = require("url");
                    const config = process.argv[1];
                    const proc = SPAWN("'$(which node)'", [
                        "--inspect-brk",
                        "nightwatch",
                        "--config", "'$configPath'",
                        "--test", "'$(basename "$testRelpath")'",
                        "--env", "'$1'"
                    ]);
                    proc.stdout.on("data", process.stdout.write);
                    function launch (url) {
                        EXEC("\"'$__DIRNAME__'/../open-in-google-chrome.sh\" \"" + url + "\"", function () {});
                    }
                    proc.stderr.on("data", function (data) {
                        data = data.toString();
                        if (launch && /Debugger listening on ws:\/\//.test(data)) {

                            const wsUrl = data.match(/Debugger listening on (ws:\/\/.+)/m)[1]
                            const wsUrl_parsed = URL.parse(wsUrl);

                            BO_LIB.LIB.REQUEST("http://" + wsUrl_parsed.host + "/json/list", function (err, response, body) {
                                const meta = JSON.parse(body)[0];
                                launch(meta.devtoolsFrontendUrl);
                                launch = null;
                            });
                        }
                        process.stderr.write(data);
                    });
                '
            else
                "nightwatch" \
                    --config "${configPath}" \
                    --test "$(basename "$testRelpath")" \
                    --env "$1"
            fi
        popd > /dev/null
    }

    echo ">>>TEST_IGNORE_LINE:\d milliseconds.\$<<<"
    echo ">>>TEST_IGNORE_LINE:\d+\spassing\s\([^\)]+\)<<<"

    echo "environments: ${environments}"

    for i in $(echo $environments | sed "s/,/ /g"); do
        testEnv "$i"
    done

}
